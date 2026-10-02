<?php
/*
 * MikoPBX - free phone system for small business
 * Copyright © 2017-2025 Alexey Portnov and Nikolay Beketov
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with this program.
 * If not, see <https://www.gnu.org/licenses/>.
 */

namespace MikoPBX\PBXCoreREST\Lib\Cdr;

use MikoPBX\Common\Models\CallDetailRecords;
use MikoPBX\Common\Providers\PBXConfModulesProvider;
use MikoPBX\Modules\Config\CDRConfigInterface;
use MikoPBX\PBXCoreREST\Lib\PBXApiResult;
use Phalcon\Di\Di;

/**
 * Get list of CDR records action
 *
 * Unified endpoint that supports both:
 * - REST API format (for CRM integration)
 * - DataTables format (for web UI)
 *
 * Format is automatically detected by presence of 'draw' parameter.
 *
 * @package MikoPBX\PBXCoreREST\Lib\Cdr
 */
class GetListAction
{
    /**
     * Get list of CDR records
     *
     * Returns REST API format only.
     * Frontend is responsible for transforming to DataTables format if needed.
     *
     * @param array $data Request parameters
     * @param array $sessionContext Session context from REST API (role, user_name, session_id).
     *                              Passed to module hooks for ACL filtering.
     * @return PBXApiResult
     */
    public static function main(array $data, array $sessionContext = []): PBXApiResult
    {
        $res = new PBXApiResult();
        $res->processor = __METHOD__;

        try {
            // Always return REST format with grouped records
            // WHY: Single format, easier maintenance, reusable for CRM and WebUI
            $result = self::handleRestRequest($data, $sessionContext);

            // WHY: Follow REST API protocol - all data inside 'data' block
            // Structure: {data: {records: [...], pagination: {...}, departments: [...]}}
            $res->data = [
                'records' => $result['data'],
                'pagination' => $result['pagination'],
                'departments' => $result['departments'] ?? [],
            ];
            $res->success = true;

        } catch (\InvalidArgumentException $e) {
            // WHY: Validation errors (date range, negative offset) return 422
            $res->success = false;
            $res->messages['error'][] = $e->getMessage();
            $res->httpCode = 422;
        } catch (\Exception $e) {
            // WHY: Unexpected errors return 500 Internal Server Error
            $res->success = false;
            $res->messages['error'][] = $e->getMessage();
            $res->httpCode = 500;
        }

        return $res;
    }


    /**
     * Handle REST API request
     *
     * Uses CDRDatabaseProvider::getCdr() to support ACL filtering from modules.
     *
     * Supports:
     * - Pagination (limit/offset or idFrom)
     * - Filtering (dateFrom/dateTo, src_num, dst_num, disposition, did)
     * - Sorting (sort/order)
     * - Grouping (grouped=true for linkedid aggregation)
     * - Field selection (fields parameter)
     * - ACL filtering via module hooks
     *
     * @param array $data Request parameters
     * @param array $sessionContext Session context from REST API for ACL filtering
     * @return array Response with data and pagination
     */
    private static function handleRestRequest(array $data, array $sessionContext = []): array
    {
        // Pagination parameters
        // WHY: Clamp limit to 1-1000 range to prevent excessive queries
        $limit = min(max(1, intval($data['limit'] ?? 50)), 1000);

        // WHY: Reject negative offset with validation error
        // Security: Negative offsets can cause unintended database behavior
        $requestedOffset = intval($data['offset'] ?? 0);
        if ($requestedOffset < 0) {
            throw new \InvalidArgumentException(
                "Invalid offset value: {$requestedOffset}. Offset must be non-negative."
            );
        }
        $offset = $requestedOffset;

        $idFrom = isset($data['idFrom']) ? intval($data['idFrom']) : null;

        // Filtering parameters
        $dateFrom = isset($data['dateFrom']) && is_string($data['dateFrom']) ? $data['dateFrom'] : null;
        $dateTo = isset($data['dateTo']) && is_string($data['dateTo']) ? $data['dateTo'] : null;
        $srcNum = isset($data['src_num']) && is_string($data['src_num']) ? $data['src_num'] : null;
        $dstNum = isset($data['dst_num']) && is_string($data['dst_num']) ? $data['dst_num'] : null;
        $disposition = isset($data['disposition']) && is_string($data['disposition']) ? $data['disposition'] : null;
        $did = isset($data['did']) && is_string($data['did']) ? $data['did'] : null;
        $linkedid = isset($data['linkedid']) && is_string($data['linkedid']) ? $data['linkedid'] : null;
        $search = isset($data['search']) && is_string($data['search']) ? $data['search'] : null;
        // Min talk time in seconds (billsec). 0 / empty = no filter.
        $billsecMin = isset($data['billsecMin']) ? intval($data['billsecMin']) : 0;
        if ($billsecMin < 0) {
            $billsecMin = 0;
        }

        // Analytics filters (Mango-style)
        $callerType = isset($data['callerType']) && is_string($data['callerType'])
            ? strtolower(trim($data['callerType'])) : 'any';
        if (!in_array($callerType, ['any', 'client', 'employee'], true)) {
            $callerType = 'any';
        }
        $clientNumber = isset($data['clientNumber']) && is_string($data['clientNumber'])
            ? trim($data['clientNumber']) : '';
        $participants = isset($data['participants']) && is_string($data['participants'])
            ? trim($data['participants']) : '';

        // Department filter: queue ext (2001) or UsersGroups id (ug-1)
        $department = isset($data['department']) && is_string($data['department'])
            ? trim($data['department']) : '';
        if ($department === 'any' || $department === '__ALL__') {
            $department = '';
        }

        // dstNumbers: comma-separated list or array
        $dstNumbers = [];
        if (isset($data['dstNumbers'])) {
            if (is_array($data['dstNumbers'])) {
                $dstNumbers = $data['dstNumbers'];
            } elseif (is_string($data['dstNumbers'])) {
                $dstNumbers = preg_split('/[\s,;]+/', $data['dstNumbers']) ?: [];
            }
        }
        $dstNumbers = array_values(array_filter(array_map('strval', $dstNumbers), static function ($n) {
            return $n !== '' && $n !== '__ALL__';
        }));

        // Normalize date filters to include time
        // WHY: Database field 'start' contains timestamp, but users provide date-only values
        // Example: '2025-10-13' should match records from '2025-10-13 00:00:00' to '2025-10-13 23:59:59'
        if ($dateFrom !== null && strlen($dateFrom) === 10) {
            // Date-only format (YYYY-MM-DD), add start of day
            $dateFrom .= ' 00:00:00';
        }
        if ($dateTo !== null && strlen($dateTo) === 10) {
            // Date-only format (YYYY-MM-DD), add end of day
            $dateTo .= ' 23:59:59';
        }

        // Enforce date range limits to prevent excessive queries
        // WHY: Prevent DoS attacks via unlimited date ranges (e.g., dateFrom=2000-01-01&dateTo=2030-12-31)
        $maxDaysRange = 365; // Maximum 1 year range
        if ($dateFrom !== null && $dateTo !== null) {
            try {
                $dateFromObj = new \DateTime($dateFrom);
                $dateToObj = new \DateTime($dateTo);
                $daysDiff = $dateFromObj->diff($dateToObj)->days;

                if ($daysDiff > $maxDaysRange) {
                    // WHY: Throw InvalidArgumentException to return 422 validation error
                    throw new \InvalidArgumentException(
                        "Date range exceeds maximum allowed ({$maxDaysRange} days). " .
                        "Please narrow your search criteria."
                    );
                }
            } catch (\Exception $e) {
                if ($e instanceof \InvalidArgumentException) {
                    throw $e; // Re-throw validation errors
                }
                // Invalid date format - throw as validation error
                throw new \InvalidArgumentException(
                    "Invalid date format. Expected: YYYY-MM-DD or YYYY-MM-DD HH:MM:SS"
                );
            }
        }

        // Auto-apply date range if no filters specified
        // WHY: Prevent full table scans on massive datasets
        if ($dateFrom === null && $dateTo === null && $linkedid === null &&
            $srcNum === null && $dstNum === null && $search === null && $did === null) {
            // Default to last 30 days if no filters provided
            $dateTo = date('Y-m-d 23:59:59');
            $dateFrom = date('Y-m-d 00:00:00', strtotime('-30 days'));
        }

        // Sorting parameters with SQL injection protection
        // WHY: Whitelist allowed fields to prevent SQL injection in ORDER BY clause
        $allowedSortFields = [
            'id',           // Primary key
            'start',        // Call start time (most common sort)
            'linkedid',     // Group by conversation
            'src_num',      // Source number
            'dst_num',      // Destination number
            'did',          // DID number
            'disposition',  // Call status (ANSWERED, NO ANSWER, etc)
            'duration',     // Total call duration
            'billsec'       // Billable duration
        ];

        $requestedSort = $data['sort'] ?? 'id';
        $sortField = in_array($requestedSort, $allowedSortFields, true) ? $requestedSort : 'id';

        $sortOrder = strtoupper($data['order'] ?? 'DESC');
        if (!in_array($sortOrder, ['ASC', 'DESC'], true)) {
            $sortOrder = 'DESC';
        }

        // Grouping parameter
        // WHY: Support both grouped (linkedid aggregation) and ungrouped (individual records) modes
        // grouped=true: Complex calls with transfers displayed as one entity
        // grouped=false: Individual CDR records for CRM integration
        // Default: true (for web UI compatibility)
        $grouped = !isset($data['grouped']) || filter_var($data['grouped'], FILTER_VALIDATE_BOOLEAN);

        // Field selection (for future use)
        $fields = $data['fields'] ?? null;

        // ============ ACL FILTERING ============
        // WHY: Apply module ACL filters BEFORE building query
        // Modules can add conditions to restrict CDR access based on user permissions
        // Example: ModuleUsersUI can limit CDR to specific extensions only
        $parameters = [
            'conditions' => '',
            'bind' => []
        ];

        // Apply ACL filters via module hooks
        // WHY: Pass sessionContext (role, user_name from JWT) for REST API context
        // In AdminCabinet context, sessionContext is empty - modules use SessionProvider
        // In REST API context, modules should use sessionContext['role'] instead
        PBXConfModulesProvider::hookModulesMethod(
            CDRConfigInterface::APPLY_ACL_FILTERS_TO_CDR_QUERY,
            [&$parameters, $sessionContext]
        );

        // Build query conditions (Phalcon ORM format)
        // Start with ACL conditions if any were added by modules
        $conditions = [];
        $bind = [];

        if (!empty($parameters['conditions'])) {
            // Preserve ACL conditions from module hooks
            $conditions[] = $parameters['conditions'];
            if (!empty($parameters['bind'])) {
                $bind = array_merge($bind, $parameters['bind']);
            }
        }

        // Linkedid filter (exact match, highest priority)
        // WHY: If linkedid specified, it's most specific filter
        if ($linkedid !== null) {
            $conditions[] = 'linkedid = :linkedid:';
            $bind['linkedid'] = $linkedid;
        }

        // Regular filters
        if ($idFrom !== null) {
            $conditions[] = 'id > :idFrom:';
            $bind['idFrom'] = $idFrom;
        }

        if ($dateFrom !== null) {
            $conditions[] = 'start >= :dateFrom:';
            $bind['dateFrom'] = $dateFrom;
        }

        if ($dateTo !== null) {
            $conditions[] = 'start <= :dateTo:';
            $bind['dateTo'] = $dateTo;
        }

        // Smart search: search phrase in CDR fields + Extensions lookup
        // WHY: Users want to search by phone number OR employee name
        // Example: "Smith" finds all calls where src_num/dst_num matches extension with "Smith" in search_index
        if ($search !== null && trim($search) !== '') {
            $searchTrimmed = trim($search);

            // STEP 1: Find matching extension numbers using ORM
            // WHY: User might search by employee name, need to find their extension numbers
            $extensionNumbers = [];
            try {
                $extensions = \MikoPBX\Common\Models\Extensions::find([
                    'conditions' => 'search_index LIKE :pattern:',
                    'bind' => ['pattern' => '%' . $searchTrimmed . '%'],
                    'columns' => 'number'
                ]);

                foreach ($extensions as $ext) {
                    $extensionNumbers[] = $ext->number;
                }

                // Extensions found - will be used in CDR query
            } catch (\Exception $e) {
                // If Extensions search fails, continue with CDR-only search
                // WHY: Graceful degradation - search will still work with LIKE on CDR fields
            }

            // STEP 2: Build OR condition for CDR search
            // Search by: LIKE phrase in src_num/dst_num/did OR exact match with found extension numbers
            $searchConditions = [];

            // LIKE search in CDR fields (for direct number search)
            $searchConditions[] = 'src_num LIKE :searchLike:';
            $searchConditions[] = 'dst_num LIKE :searchLike:';
            $searchConditions[] = 'did LIKE :searchLike:';
            $bind['searchLike'] = '%' . $searchTrimmed . '%';

            // Exact match with extension numbers (for name-based search)
            if (!empty($extensionNumbers)) {
                $searchConditions[] = 'src_num IN ({extNumbers:array})';
                $searchConditions[] = 'dst_num IN ({extNumbers:array})';
                $bind['extNumbers'] = $extensionNumbers;
            }

            $conditions[] = '(' . implode(' OR ', $searchConditions) . ')';
        }

        if ($srcNum !== null) {
            $conditions[] = 'src_num LIKE :srcNum:';
            $bind['srcNum'] = '%' . $srcNum . '%';
        }

        if ($dstNum !== null) {
            $conditions[] = 'dst_num LIKE :dstNum:';
            $bind['dstNum'] = '%' . $dstNum . '%';
        }

        // Звонки: SUCCESS / FAIL / concrete disposition
        if ($disposition !== null && $disposition !== '' && strtoupper($disposition) !== 'ALL') {
            $disp = strtoupper($disposition);
            if ($disp === 'SUCCESS') {
                $conditions[] = "disposition IN ('ANSWERED','ANSWER')";
            } elseif ($disp === 'FAIL') {
                $conditions[] = "disposition NOT IN ('ANSWERED','ANSWER')";
            } else {
                $conditions[] = 'disposition = :disposition:';
                $bind['disposition'] = $disposition;
            }
        }

        if ($did !== null) {
            $conditions[] = 'did LIKE :did:';
            $bind['did'] = '%' . $did . '%';
        }

        // Кто звонил: client vs employee (by Extensions list)
        if ($callerType === 'client' || $callerType === 'employee') {
            $extNumbers = [];
            try {
                $extensions = \MikoPBX\Common\Models\Extensions::find(['columns' => 'number']);
                foreach ($extensions as $ext) {
                    if ($ext->number !== null && $ext->number !== '') {
                        $extNumbers[] = (string)$ext->number;
                    }
                }
            } catch (\Throwable $e) {
                $extNumbers = [];
            }
            // Fallback heuristic if extensions unavailable
            if (empty($extNumbers)) {
                if ($callerType === 'employee') {
                    $conditions[] = 'LENGTH(src_num) <= 5';
                } else {
                    $conditions[] = 'LENGTH(src_num) > 5';
                }
            } elseif ($callerType === 'employee') {
                $conditions[] = 'src_num IN ({callerExt:array})';
                $bind['callerExt'] = $extNumbers;
            } else {
                $conditions[] = 'src_num NOT IN ({callerExt:array})';
                $bind['callerExt'] = $extNumbers;
            }
        }

        // Номер клиента (часть номера в src/dst/did)
        if ($clientNumber !== '') {
            $conditions[] = '(src_num LIKE :clientNumber: OR dst_num LIKE :clientNumber: OR did LIKE :clientNumber:)';
            $bind['clientNumber'] = '%' . $clientNumber . '%';
        }

        // Куда звонил: конкретные номера АТС
        if (!empty($dstNumbers)) {
            $conditions[] = '(dst_num IN ({dstNums:array}) OR did IN ({dstNums:array}))';
            $bind['dstNums'] = $dstNumbers;
        }

        // Участники: любой из указанных номеров в src или dst
        if ($participants !== '') {
            $parts = preg_split('/[\s,;]+/', $participants) ?: [];
            $parts = array_values(array_filter(array_map('trim', $parts)));
            $partOr = [];
            foreach ($parts as $idx => $part) {
                if ($part === '') {
                    continue;
                }
                $key = 'part' . $idx;
                $partOr[] = "(src_num LIKE :{$key}: OR dst_num LIKE :{$key}: OR did LIKE :{$key}:)";
                $bind[$key] = '%' . $part . '%';
            }
            if (!empty($partOr)) {
                $conditions[] = '(' . implode(' OR ', $partOr) . ')';
            }
        }

        // Отдел: очередь или любой её сотрудник (src/dst)
        $deptMaps = self::loadDepartmentMaps();
        if ($department !== '') {
            $deptNums = self::numbersForDepartment($department, $deptMaps);
            if (!empty($deptNums)) {
                $conditions[] = '(src_num IN ({deptNums:array}) OR dst_num IN ({deptNums:array}) OR did IN ({deptNums:array}))';
                $bind['deptNums'] = $deptNums;
            }
        }

        // Ungrouped: filter each row by talk time. Grouped uses HAVING SUM(billsec) below.
        if (!$grouped && $billsecMin > 0) {
            $conditions[] = 'billsec >= :billsecMin:';
            $bind['billsecMin'] = $billsecMin;
        }

        $whereClause = !empty($conditions) ? implode(' AND ', $conditions) : '1=1';

        // Format response
        $responseData = [];
        $lastId = null;

        if ($grouped) {
            // ============ GROUPED PAGINATION LOGIC ============
            // WHY: Must paginate by groups (linkedid), not individual records
            // STEP 1: Get paginated linkedids using raw SQL (fast!)
            // STEP 2: Fetch only CDR records for these linkedids via ORM
            // STEP 3: Group and format
            // PERFORMANCE: Raw SQL for aggregation, ORM only for final data fetch

            $di = Di::getDefault();
            $dbCDR = $di->get('dbCDR');

            // Convert Phalcon placeholders to PDO format for raw SQL
            // WHY: Raw SQL uses PDO placeholders :name, but Phalcon ORM uses :name:
            $whereRaw = $whereClause;
            $bindForRawSql = $bind;

            // Handle array placeholder {extNumbers:array} for IN clause
            // WHY: Raw SQL doesn't support Phalcon's array binding, need to expand manually
            if (isset($bindForRawSql['extNumbers']) && is_array($bindForRawSql['extNumbers'])) {
                $placeholders = [];
                foreach ($bindForRawSql['extNumbers'] as $idx => $number) {
                    $key = "extNum{$idx}";
                    $placeholders[] = ":{$key}";
                    $bindForRawSql[$key] = $number;
                }
                // Replace {extNumbers:array} with :extNum0,:extNum1,:extNum2,...
                $whereRaw = str_replace('{extNumbers:array}', implode(',', $placeholders), $whereRaw);
                unset($bindForRawSql['extNumbers']);
            }

            // Handle array placeholder {filteredExtensions:array} for ACL filtering
            // WHY: ModuleUsersUI adds CDR ACL filters with this placeholder
            if (isset($bindForRawSql['filteredExtensions']) && is_array($bindForRawSql['filteredExtensions'])) {
                $placeholders = [];
                foreach ($bindForRawSql['filteredExtensions'] as $idx => $number) {
                    $key = "filtExt{$idx}";
                    $placeholders[] = ":{$key}";
                    $bindForRawSql[$key] = $number;
                }
                // Replace {filteredExtensions:array} with :filtExt0,:filtExt1,:filtExt2,...
                $whereRaw = str_replace('{filteredExtensions:array}', implode(',', $placeholders), $whereRaw);
                unset($bindForRawSql['filteredExtensions']);
            }

            // callerExt / dstNums / deptNums array placeholders for analytics filters
            foreach (['callerExt' => 'callerExt', 'dstNums' => 'dstNum', 'deptNums' => 'deptNum'] as $bindKey => $prefix) {
                if (isset($bindForRawSql[$bindKey]) && is_array($bindForRawSql[$bindKey])) {
                    $placeholders = [];
                    foreach ($bindForRawSql[$bindKey] as $idx => $number) {
                        $key = "{$prefix}{$idx}";
                        $placeholders[] = ":{$key}";
                        $bindForRawSql[$key] = $number;
                    }
                    $whereRaw = str_replace('{'.$bindKey.':array}', implode(',', $placeholders), $whereRaw);
                    unset($bindForRawSql[$bindKey]);
                }
            }

            // Replace simple Phalcon placeholders (:name:) with PDO format (:name)
            $whereRaw = str_replace(
                [':linkedid:', ':idFrom:', ':dateFrom:', ':dateTo:', ':searchLike:', ':srcNum:', ':dstNum:', ':disposition:', ':did:', ':billsecMin:', ':clientNumber:'],
                [':linkedid', ':idFrom', ':dateFrom', ':dateTo', ':searchLike', ':srcNum', ':dstNum', ':disposition', ':did', ':billsecMin', ':clientNumber'],
                $whereRaw
            );

            // Replace dynamically created placeholders (extNum*, filtExt*, callerExt*, dstNum*, part*)
            foreach (array_keys($bindForRawSql) as $key) {
                $whereRaw = str_replace(":{$key}:", ":{$key}", $whereRaw);
            }

            // Group-level talk filter: SUM(billsec) across all legs of the call
            // WHY: Inline int — PDO named binds in HAVING fail on SQLite via Phalcon (return empty).
            $havingClause = '';
            if ($billsecMin > 0) {
                $havingClause = 'HAVING SUM(billsec) >= ' . $billsecMin;
            }

            // Count total unique linkedids
            // WHY: Need for pagination metadata
            if ($havingClause !== '') {
                $countSql = "
                    SELECT COUNT(*) as total FROM (
                        SELECT linkedid
                        FROM cdr_general
                        WHERE {$whereRaw}
                        GROUP BY linkedid
                        {$havingClause}
                    ) AS filtered_groups
                ";
            } else {
                $countSql = "SELECT COUNT(DISTINCT linkedid) as total FROM cdr_general WHERE {$whereRaw}";
            }
            $totalRows = $dbCDR->fetchAll($countSql, \Phalcon\Db\Enum::FETCH_ASSOC, $bindForRawSql);
            $total = !empty($totalRows) ? (int)$totalRows[0]['total'] : 0;

            // Get paginated list of unique linkedids
            // WHY: Only fetch linkedids for current page (memory efficient)
            // WHY GROUP BY: For grouped mode, use MAX() aggregation to get correct sort value per linkedid
            // Example: If sorting by 'id DESC', we want linkedid with MAX(id), not just any record's id
            $linkedIdsSql = "
                SELECT linkedid, MAX({$sortField}) as sort_value
                FROM cdr_general
                WHERE {$whereRaw}
                GROUP BY linkedid
                {$havingClause}
                ORDER BY sort_value {$sortOrder}
                LIMIT {$limit} OFFSET {$offset}
            ";

            $linkedIdsRows = $dbCDR->fetchAll($linkedIdsSql, \Phalcon\Db\Enum::FETCH_ASSOC, $bindForRawSql);
            $linkedIds = array_column($linkedIdsRows, 'linkedid');

            if (!empty($linkedIds)) {
                // Fetch all CDR records for selected linkedids using ORM
                // WHY: ORM handles object mapping and relationships well
                $records = CallDetailRecords::find([
                    'conditions' => 'linkedid IN ({linkedIds:array})',
                    'bind' => ['linkedIds' => $linkedIds],
                    'order' => "{$sortField} {$sortOrder}"
                ]);

                // Group by linkedid for display and enrich with department / agent
                $groupedData = self::groupByLinkedId($records);
                $groupedData = self::enrichGroupsWithDepartment($groupedData, $deptMaps);
                $responseData = array_values($groupedData);

                // Get last ID from grouped data
                if (!empty($groupedData)) {
                    $lastGroup = end($groupedData);
                    if (isset($lastGroup['records']) && !empty($lastGroup['records'])) {
                        $lastRecord = end($lastGroup['records']);
                        $lastId = $lastRecord['id'] ?? null;
                    }
                }
            }

        } else {
            // ============ INDIVIDUAL RECORD PAGINATION ============
            // WHY: Simple pagination for ungrouped view

            $queryParams = [
                'conditions' => $whereClause,
                'bind' => $bind,
                'limit' => $limit,
                'offset' => $offset,
                'order' => "{$sortField} {$sortOrder}"
            ];

            $records = CallDetailRecords::find($queryParams);

            // Return individual records - convert to array for PHPStan
            $recordsArray = iterator_to_array($records);
            foreach ($recordsArray as $record) {
                $item = DataStructure::createFromModel($record);
                $meta = self::resolveDepartmentMeta([
                    'src_num' => $record->src_num ?? '',
                    'dst_num' => $record->dst_num ?? '',
                    'did' => $record->did ?? '',
                    'disposition' => $record->disposition ?? '',
                    'records' => [$item],
                ], $deptMaps);
                $responseData[] = array_merge($item, $meta);
            }

            // Count total individual records
            $total = CallDetailRecords::count([
                'conditions' => $whereClause,
                'bind' => $bind
            ]);

            // Get last ID
            if (!empty($recordsArray)) {
                $lastRecord = end($recordsArray);
                $lastId = $lastRecord->id;
            }
        }

        return [
            'data' => $responseData,
            'pagination' => [
                'total' => $total,
                'limit' => $limit,
                'offset' => $offset,
                'hasMore' => ($offset + $limit) < $total,
                'lastId' => $lastId
            ],
            // Filter options for UI (ModuleUsersGroups + Call Queues)
            'departments' => self::departmentFilterOptions($deptMaps),
        ];
    }

    /**
     * Group CDR records by linkedid
     *
     * WHY: Complex calls with transfers have multiple CDR records with same linkedid
     * Grouping provides a single view of the entire call flow with all segments
     *
     * @param \Phalcon\Mvc\Model\ResultsetInterface|CallDetailRecords[] $records CDR records to group
     * @return array<string, array<string, mixed>> Grouped records indexed by linkedid
     */
    private static function groupByLinkedId($records): array
    {
        $grouped = [];

        /** @var CallDetailRecords $record */
        foreach ($records as $record) {
            $linkedId = $record->linkedid;

            if (!isset($grouped[$linkedId])) {
                // Initialize group with first record's data
                $grouped[$linkedId] = [
                    'linkedid' => $linkedId,
                    'start' => $record->start,
                    'src_num' => $record->src_num,
                    'src_name' => $record->src_name ?? '',
                    'dst_num' => $record->dst_num,  // Initial value
                    'dst_name' => $record->dst_name ?? '',
                    'did' => $record->did,          // Initial DID value
                    'disposition' => $record->disposition,
                    'totalDuration' => 0,
                    'totalBillsec' => 0,
                    'records' => []
                ];
            }

            // Update start: always use earliest timestamp
            // WHY: Group should show when the call actually started, not first record in query result
            $currentStart = $grouped[$linkedId]['start'];

            // Compare timestamps as strings (format: YYYY-MM-DD HH:MM:SS.mmm)
            // WHY: String comparison works correctly for ISO datetime format
            if ($record->start < $currentStart) {
                $grouped[$linkedId]['start'] = $record->start;
                // When we find earlier start, also update src_num and src_name from that record
                // WHY: The earliest record shows the original caller
                if (empty($grouped[$linkedId]['src_num']) || $record->start < $currentStart) {
                    $grouped[$linkedId]['src_num'] = $record->src_num;
                    $grouped[$linkedId]['src_name'] = $record->src_name ?? '';
                }
            }

            // Update dst_num: always prefer DID if present in ANY record
            // WHY: For incoming calls, users want to see which external number (DID) was called
            // not the first internal extension in transfer chain
            if (!empty($record->did)) {
                // If this record has DID, always use it as dst_num for display
                $grouped[$linkedId]['dst_num'] = $record->did;
                // Clear dst_name: DID is an external number, not an employee extension,
                // so showing employee name next to DID is misleading (#1029 feedback)
                $grouped[$linkedId]['dst_name'] = '';
                // Also update the group's DID field to ensure consistency
                $grouped[$linkedId]['did'] = $record->did;
            }

            // Update aggregated metrics
            $grouped[$linkedId]['totalDuration'] += intval($record->duration);
            $grouped[$linkedId]['totalBillsec'] += intval($record->billsec);

            // Update disposition if current is ANSWERED
            if (($record->disposition === 'ANSWERED' || $record->disposition === 'ANSWER')
                && $grouped[$linkedId]['disposition'] !== 'ANSWERED') {
                $grouped[$linkedId]['disposition'] = 'ANSWERED';
            }

            // Add individual record to group
            $grouped[$linkedId]['records'][] = DataStructure::createFromModel($record);
        }

        // Sort records within each group by start time ascending
        // WHY: Display call flow in chronological order (IVR → Queue → Employee)
        foreach ($grouped as &$group) {
            usort($group['records'], static function (array $a, array $b): int {
                return $a['start'] <=> $b['start'];
            });
        }
        unset($group);

        return $grouped;
    }

    /**
     * Load Call Queues + ModuleUsersGroups (created departments) maps.
     *
     * @return array{
     *   queues: array<string,string>,
     *   memberToQueues: array<string,list<array{ext:string,name:string,priority:int}>>,
     *   userGroups: array<string,string>,
     *   memberToUserGroup: array<string,array{id:string,name:string}>,
     *   extNames: array<string,string>
     * }
     */
    private static function loadDepartmentMaps(): array
    {
        $queues = [];
        $memberToQueues = [];
        $extNames = [];
        $queueByUniq = [];
        $userGroups = [];
        $memberToUserGroup = [];

        try {
            $rows = \MikoPBX\Common\Models\CallQueues::find();
            foreach ($rows as $q) {
                $ext = (string)($q->extension ?? '');
                $name = (string)($q->name ?? $ext);
                $uniq = (string)($q->uniqid ?? '');
                if ($ext !== '') {
                    $queues[$ext] = $name;
                }
                if ($uniq !== '') {
                    $queueByUniq[$uniq] = ['ext' => $ext, 'name' => $name];
                }
            }
        } catch (\Throwable $e) {
            // ignore
        }

        try {
            $members = \MikoPBX\Common\Models\CallQueueMembers::find();
            foreach ($members as $m) {
                $memberExt = (string)($m->extension ?? '');
                $qUniq = (string)($m->queue ?? '');
                if ($memberExt === '' || !isset($queueByUniq[$qUniq])) {
                    continue;
                }
                $info = $queueByUniq[$qUniq];
                if ($info['ext'] === '') {
                    continue;
                }
                $memberToQueues[$memberExt][] = [
                    'ext' => $info['ext'],
                    'name' => $info['name'],
                    'priority' => (int)($m->priority ?? 99),
                ];
            }
            foreach ($memberToQueues as &$list) {
                usort($list, static function (array $a, array $b): int {
                    return $a['priority'] <=> $b['priority'];
                });
            }
            unset($list);
        } catch (\Throwable $e) {
            // ignore
        }

        // queueExt → member extensions (for mapping queues → UsersGroups)
        $queueMembers = [];
        foreach ($memberToQueues as $ext => $list) {
            foreach ($list as $row) {
                $qExt = (string)($row['ext'] ?? '');
                if ($qExt === '') {
                    continue;
                }
                if (!isset($queueMembers[$qExt])) {
                    $queueMembers[$qExt] = [];
                }
                if (!in_array((string)$ext, $queueMembers[$qExt], true)) {
                    $queueMembers[$qExt][] = (string)$ext;
                }
            }
        }

        // userid → SIP extension number
        $userIdToExt = [];
        try {
            $extensions = \MikoPBX\Common\Models\Extensions::find([
                'conditions' => "type = 'SIP'",
                'columns' => 'number,callerid,userid',
            ]);
            foreach ($extensions as $ext) {
                $num = (string)($ext->number ?? '');
                if ($num === '') {
                    continue;
                }
                $extNames[$num] = (string)($ext->callerid ?? $num);
                $uid = (string)($ext->userid ?? '');
                if ($uid !== '') {
                    $userIdToExt[$uid] = $num;
                }
            }
        } catch (\Throwable $e) {
            // ignore
        }

        // ModuleUsersGroups — «созданные телефонные группы» / отделы
        try {
            if (class_exists(\Modules\ModuleUsersGroups\Models\UsersGroups::class)
                && class_exists(\Modules\ModuleUsersGroups\Models\GroupMembers::class)
            ) {
                $gRows = \Modules\ModuleUsersGroups\Models\UsersGroups::find();
                foreach ($gRows as $g) {
                    $gid = (string)($g->id ?? '');
                    $gname = trim((string)($g->name ?? ''));
                    if ($gid !== '' && $gname !== '') {
                        $userGroups[$gid] = $gname;
                    }
                }
                $mRows = \Modules\ModuleUsersGroups\Models\GroupMembers::find();
                foreach ($mRows as $m) {
                    $gid = (string)($m->group_id ?? '');
                    $uid = (string)($m->user_id ?? '');
                    if ($gid === '' || $uid === '' || !isset($userGroups[$gid])) {
                        continue;
                    }
                    $extNum = $userIdToExt[$uid] ?? '';
                    if ($extNum === '') {
                        continue;
                    }
                    // One primary group per extension (first wins; UI usually has one)
                    if (!isset($memberToUserGroup[$extNum])) {
                        $memberToUserGroup[$extNum] = [
                            'id' => $gid,
                            'name' => $userGroups[$gid],
                        ];
                    }
                }
            }
        } catch (\Throwable $e) {
            // ignore — module may be disabled
        }

        // SQLite fallback if ORM models unavailable
        if (empty($userGroups)) {
            $modDb = '/storage/usbdisk1/mikopbx/custom_modules/ModuleUsersGroups/db/module.db';
            $mainDb = '/cf/conf/mikopbx.db';
            if (is_file($modDb) && is_file($mainDb)) {
                try {
                    $pdoMod = new \PDO('sqlite:' . $modDb);
                    $pdoMain = new \PDO('sqlite:' . $mainDb);
                    foreach ($pdoMod->query('SELECT id, name FROM m_ModuleUsersGroups_UsersGroups') as $row) {
                        $gid = (string)$row['id'];
                        $gname = trim((string)$row['name']);
                        if ($gid !== '' && $gname !== '') {
                            $userGroups[$gid] = $gname;
                        }
                    }
                    $uidExt = [];
                    foreach ($pdoMain->query("SELECT number, userid FROM m_Extensions WHERE type='SIP'") as $row) {
                        $uid = (string)$row['userid'];
                        $num = (string)$row['number'];
                        if ($uid !== '' && $num !== '') {
                            $uidExt[$uid] = $num;
                        }
                    }
                    foreach ($pdoMod->query('SELECT group_id, user_id FROM m_ModuleUsersGroups_GroupMembers') as $row) {
                        $gid = (string)$row['group_id'];
                        $uid = (string)$row['user_id'];
                        $extNum = $uidExt[$uid] ?? '';
                        if ($extNum === '' || !isset($userGroups[$gid]) || isset($memberToUserGroup[$extNum])) {
                            continue;
                        }
                        $memberToUserGroup[$extNum] = [
                            'id' => $gid,
                            'name' => $userGroups[$gid],
                        ];
                    }
                } catch (\Throwable $e) {
                    // ignore
                }
            }
        }

        // Map each Call Queue → ModuleUsersGroups department (by members + name)
        $queueToUserGroup = [];
        $ugMembers = [];
        foreach ($memberToUserGroup as $ext => $info) {
            $gid = (string)($info['id'] ?? '');
            if ($gid === '') {
                continue;
            }
            if (!isset($ugMembers[$gid])) {
                $ugMembers[$gid] = [];
            }
            $ugMembers[$gid][] = (string)$ext;
        }
        foreach ($queues as $qExt => $qName) {
            $qMems = $queueMembers[$qExt] ?? [];
            $bestId = '';
            $bestScore = 0;
            $ql = mb_strtolower((string)$qName);
            foreach ($userGroups as $gid => $gname) {
                $score = count(array_intersect($qMems, $ugMembers[$gid] ?? []));
                $gl = mb_strtolower((string)$gname);
                if ($ql === $gl) {
                    $score += 100;
                } elseif (
                    (preg_match('/поддерж/u', $ql) && preg_match('/поддерж/u', $gl))
                    || (preg_match('/продаж/u', $ql) && preg_match('/продаж/u', $gl))
                    || (preg_match('/тех/u', $ql) && preg_match('/тех/u', $gl))
                ) {
                    $score += 50;
                }
                if ($score > $bestScore) {
                    $bestScore = $score;
                    $bestId = (string)$gid;
                }
            }
            if ($bestId !== '' && $bestScore > 0) {
                $queueToUserGroup[$qExt] = [
                    'id' => $bestId,
                    'name' => $userGroups[$bestId],
                ];
            }
        }

        return [
            'queues' => $queues,
            'memberToQueues' => $memberToQueues,
            'queueMembers' => $queueMembers,
            'userGroups' => $userGroups,
            'memberToUserGroup' => $memberToUserGroup,
            'queueToUserGroup' => $queueToUserGroup,
            'extNames' => $extNames,
        ];
    }

    /**
     * Options for the «Отдел» filter dropdown.
     *
     * @param array $maps
     * @return list<array{value:string,label:string}>
     */
    private static function departmentFilterOptions(array $maps): array
    {
        // Only «созданные» groups from ModuleUsersGroups — same names as in history
        $opts = [];
        foreach (($maps['userGroups'] ?? []) as $id => $name) {
            $opts[] = ['value' => 'ug-' . $id, 'label' => (string)$name];
        }
        usort($opts, static function (array $a, array $b): int {
            return strcmp($a['label'], $b['label']);
        });
        return $opts;
    }

    /**
     * Numbers that belong to a department filter (UsersGroup or Call Queue).
     *
     * @param string $department ug-1 or queue ext 2001
     * @param array $maps From loadDepartmentMaps()
     * @return list<string>
     */
    private static function numbersForDepartment(string $department, array $maps): array
    {
        $nums = [];

        // ModuleUsersGroups: ug-{id} — members + mapped queues
        if (strpos($department, 'ug-') === 0) {
            $gid = substr($department, 3);
            foreach (($maps['memberToUserGroup'] ?? []) as $ext => $info) {
                if ((string)($info['id'] ?? '') === $gid) {
                    $nums[] = (string)$ext;
                }
            }
            foreach (($maps['queueToUserGroup'] ?? []) as $qExt => $info) {
                if ((string)($info['id'] ?? '') === $gid) {
                    $nums[] = (string)$qExt;
                    foreach (($maps['queueMembers'][$qExt] ?? []) as $mExt) {
                        $nums[] = (string)$mExt;
                    }
                }
            }
            return array_values(array_unique($nums));
        }

        // Call Queue extension
        $nums = [$department];
        foreach ($maps['memberToQueues'] as $ext => $list) {
            foreach ($list as $row) {
                if ((string)$row['ext'] === $department) {
                    $nums[] = (string)$ext;
                    break;
                }
            }
        }
        return array_values(array_unique($nums));
    }

    /**
     * @param array<string, array<string, mixed>> $groups
     * @param array $maps
     * @return array<string, array<string, mixed>>
     */
    private static function enrichGroupsWithDepartment(array $groups, array $maps): array
    {
        foreach ($groups as $linkedId => $group) {
            $groups[$linkedId] = array_merge($group, self::resolveDepartmentMeta($group, $maps));
        }
        return $groups;
    }

    /**
     * Resolve department / agent labels for a grouped (or single) call.
     *
     * Priority:
     * 1) Queue dialed in CDR → that queue (what client called)
     * 2) ModuleUsersGroups membership of the relevant employee (created departments)
     * 3) Single Call Queue membership (fallback)
     * 4) "—"
     *
     * @param array<string, mixed> $group
     * @param array $maps
     * @return array<string, mixed>
     */
    private static function resolveDepartmentMeta(array $group, array $maps): array
    {
        $queues = $maps['queues'] ?? [];
        $memberToQueues = $maps['memberToQueues'] ?? [];
        $memberToUserGroup = $maps['memberToUserGroup'] ?? [];
        $extNames = $maps['extNames'] ?? [];

        $deptExt = '';
        $deptName = '';
        $deptSource = '';
        $answeredBy = '';
        $answeredByName = '';
        $missedBy = [];
        $missedByNames = [];
        $queueHit = false;

        $records = $group['records'] ?? [];
        if (!is_array($records) || empty($records)) {
            $records = [[
                'src_num' => $group['src_num'] ?? '',
                'dst_num' => $group['dst_num'] ?? '',
                'did' => $group['did'] ?? '',
                'disposition' => $group['disposition'] ?? '',
            ]];
        }

        $isAnswered = in_array(
            strtoupper(str_replace(' ', '', (string)($group['disposition'] ?? ''))),
            ['ANSWERED', 'ANSWER'],
            true
        );

        $groupSrc = (string)($group['src_num'] ?? '');
        $groupDst = (string)($group['dst_num'] ?? '');
        $groupDid = (string)($group['did'] ?? '');

        // --- Pass 1: queue destination in CDR legs ---
        foreach ($records as $rec) {
            if (!is_array($rec)) {
                continue;
            }
            $dst = (string)($rec['dst_num'] ?? '');
            if ($dst !== '' && isset($queues[$dst])) {
                $deptExt = $dst;
                $deptName = $queues[$dst];
                $deptSource = 'queue';
                $queueHit = true;
                break;
            }
        }
        if (!$queueHit) {
            foreach ([$groupDst, $groupDid] as $cand) {
                if ($cand !== '' && isset($queues[$cand])) {
                    $deptExt = $cand;
                    $deptName = $queues[$cand];
                    $deptSource = 'queue';
                    $queueHit = true;
                    break;
                }
            }
        }

        // Prefer ModuleUsersGroups name for the dialed queue (same labels as in «Телефонные группы»)
        if ($queueHit && $deptExt !== '') {
            $mapped = ($maps['queueToUserGroup'] ?? [])[$deptExt] ?? null;
            if (is_array($mapped) && !empty($mapped['name'])) {
                $deptName = (string)$mapped['name'];
                $deptExt = 'ug-' . $mapped['id'];
                $deptSource = 'usergroup';
            } else {
                // Fallback: fuzzy name match against UsersGroups
                foreach (($maps['userGroups'] ?? []) as $gid => $gname) {
                    $g = mb_strtolower((string)$gname);
                    $q = mb_strtolower($deptName);
                    $match = ($g === $q)
                        || (preg_match('/поддерж/u', $q) && preg_match('/поддерж/u', $g))
                        || (preg_match('/продаж/u', $q) && preg_match('/продаж/u', $g));
                    if ($match) {
                        $deptName = (string)$gname;
                        $deptExt = 'ug-' . $gid;
                        $deptSource = 'usergroup';
                        break;
                    }
                }
            }
        }

        // --- Pass 2: who answered / missed ---
        foreach ($records as $rec) {
            if (!is_array($rec)) {
                continue;
            }
            $dst = (string)($rec['dst_num'] ?? '');
            if ($dst === '' || !isset($extNames[$dst])) {
                continue;
            }
            $disp = strtoupper(str_replace(' ', '', (string)($rec['disposition'] ?? '')));
            $legAnswered = in_array($disp, ['ANSWERED', 'ANSWER'], true);
            if ($legAnswered) {
                $answeredBy = $dst;
                $answeredByName = $extNames[$dst];
            } elseif (!in_array($dst, $missedBy, true)) {
                $missedBy[] = $dst;
                $missedByNames[] = $extNames[$dst];
            }
        }

        $srcIsInternal = $groupSrc !== '' && (isset($extNames[$groupSrc]) || isset($queues[$groupSrc]) || isset($memberToQueues[$groupSrc]) || isset($memberToUserGroup[$groupSrc]));
        $dstIsInternal = $groupDst !== '' && (isset($extNames[$groupDst]) || isset($queues[$groupDst]) || isset($memberToQueues[$groupDst]) || isset($memberToUserGroup[$groupDst]));
        $dstIsExternal = $groupDst !== '' && !$dstIsInternal && !isset($queues[$groupDst]);
        $isOutbound = $srcIsInternal && $dstIsExternal;
        $isInbound = !$isOutbound && ($dstIsInternal || $queueHit || $groupDid !== '');

        // --- Pass 3: created UsersGroups for the relevant employee ---
        if (!$queueHit) {
            $candidateExt = '';
            if ($isOutbound && $srcIsInternal) {
                $candidateExt = $groupSrc;
            } elseif ($answeredBy !== '') {
                $candidateExt = $answeredBy;
            } elseif (!empty($missedBy)) {
                $candidateExt = $missedBy[0];
            } elseif ($isInbound && isset($extNames[$groupDst])) {
                $candidateExt = $groupDst;
            } elseif ($srcIsInternal) {
                $candidateExt = $groupSrc;
            }

            if ($candidateExt !== '' && isset($memberToUserGroup[$candidateExt])) {
                $ug = $memberToUserGroup[$candidateExt];
                $deptExt = 'ug-' . $ug['id'];
                $deptName = (string)$ug['name'];
                $deptSource = 'usergroup';
            } elseif ($candidateExt !== '' && !empty($memberToQueues[$candidateExt]) && count($memberToQueues[$candidateExt]) === 1) {
                // Fallback: single queue membership → remapped UsersGroup when possible
                $qExt = (string)$memberToQueues[$candidateExt][0]['ext'];
                $mapped = ($maps['queueToUserGroup'] ?? [])[$qExt] ?? null;
                if (is_array($mapped) && !empty($mapped['name'])) {
                    $deptExt = 'ug-' . $mapped['id'];
                    $deptName = (string)$mapped['name'];
                    $deptSource = 'usergroup';
                } else {
                    $deptExt = $qExt;
                    $deptName = (string)$memberToQueues[$candidateExt][0]['name'];
                    $deptSource = 'queue-member';
                }
            }
        }

        $agentExt = '';
        $agentName = '';
        $agentRole = '';
        if ($isAnswered && $answeredBy !== '') {
            $agentExt = $answeredBy;
            $agentName = $answeredByName;
            $agentRole = 'answered';
        } elseif (!$isAnswered && !empty($missedBy)) {
            $agentExt = implode(',', $missedBy);
            $agentName = implode(', ', $missedByNames);
            $agentRole = 'missed';
        }

        $departmentLabel = $deptName !== '' ? $deptName : '—';
        $srcIsExternal = $groupSrc !== '' && !$srcIsInternal;
        $agentIsNotCaller = $agentExt !== '' && $agentExt !== $groupSrc
            && strpos(',' . $agentExt . ',', ',' . $groupSrc . ',') === false;
        if (
            $deptName !== ''
            && $agentRole !== ''
            && $agentName !== ''
            && $agentIsNotCaller
            && ($queueHit || $srcIsExternal || $isInbound)
        ) {
            $roleRu = $agentRole === 'answered' ? 'ответил' : 'пропустил';
            $who = trim(($agentExt !== '' && strpos($agentExt, ',') === false ? $agentExt . ' ' : '') . $agentName);
            $departmentLabel = $deptName . ' · ' . $roleRu . ' ' . $who;
        }

        return [
            'department' => $deptName,
            'departmentExt' => $deptExt,
            'departmentLabel' => $departmentLabel,
            'departmentSource' => $deptSource,
            'agentExt' => $agentExt,
            'agentName' => $agentName,
            'agentRole' => $agentRole,
            'callDirection' => $isOutbound ? 'out' : ($isInbound ? 'in' : ''),
        ];
    }
}
