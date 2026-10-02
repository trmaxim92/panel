/*
 * MikoPBX - free phone system for small business
 * Copyright © 2017-2023 Alexey Portnov and Nikolay Beketov
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

/* global globalRootUrl, SemanticLocalization, ExtensionsAPI, moment, globalTranslate, CDRPlayer, CdrAPI, UserMessage, ACLHelper, SecurityUtils */

/**
 * callDetailRecords module.
 * @module callDetailRecords
 */
const callDetailRecords = {
    /**
     * The call detail records table element.
     * Resolved in initialize() — must not call $() at module-load time.
     * @type {jQuery}
     */
    $cdrTable: null,

    /**
     * The global search input element.
     * @type {jQuery}
     */
    $globalSearch: null,

    /**
     * The date range selector element.
     * @type {jQuery}
     */
    $dateRangeSelector: null,

    /**
     * The search CDR input element.
     * @type {jQuery}
     */
    $searchCDRInput: null,

    /**
     * The page length selector.
     * @type {jQuery}
     */
    $pageLengthSelector: null,

    /**
     * The data table object.
     * @type {Object}
     */
    dataTable: {},

    /**
     * An array of players.
     * @type {Array}
     */
    players: [],

    /**
     * Flag indicating if CDR database has any records
     * @type {boolean}
     */
    hasCDRRecords: true,

    /**
     * The empty database placeholder element
     * @type {jQuery}
     */
    $emptyDatabasePlaceholder: null,

    /**
     * Storage key for filter state in sessionStorage
     * @type {string}
     */
    STORAGE_KEY: 'cdr_filters_state',

    /** Default min talk time (seconds). 0 = show all calls */
    DEFAULT_BILLSEC_MIN: 0,

    $statusFilter: null,
    $billsecMin: null,
    $callerType: null,
    $department: null,
    $clientNumber: null,
    $dstNumbers: null,
    $participants: null,

    /**
     * Flag to track if DataTable has completed initialization
     * WHY: Prevents saving state during initial load before filters are restored
     * @type {boolean}
     */
    isInitialized: false,

    /**
     * Initializes the call detail records.
     */
    initialize() {
        // Hide stock Miko page header (duplicate with ss-cdr-page-head)
        $('#page-header').hide();
        $('body').addClass('ss-cdr-route');
        // Match mock search placeholder even if translation cache is stale
        $('#top-menu-search input.search').attr(
            'placeholder',
            'Поиск по номеру, клиенту, звонку...',
        );

        callDetailRecords.$cdrTable = $('#cdr-table');
        callDetailRecords.$globalSearch = $('#globalsearch');
        callDetailRecords.$dateRangeSelector = $('#date-range-selector');
        callDetailRecords.$searchCDRInput = $('#search-cdr-input');
        callDetailRecords.$pageLengthSelector = $('#page-length-select');
        callDetailRecords.$emptyDatabasePlaceholder = $('#cdr-empty-database-placeholder');
        callDetailRecords.$statusFilter = $('#cdr-status-filter');
        callDetailRecords.$billsecMin = $('#cdr-billsec-min');
        callDetailRecords.$callerType = $('#cdr-caller-type');
        callDetailRecords.$department = $('#cdr-department');
        callDetailRecords.$clientNumber = $('#cdr-client-number');
        callDetailRecords.$dstNumbers = $('#cdr-dst-numbers');
        callDetailRecords.$participants = $('#cdr-participants');

        // Dropdowns must never block calendar/table boot
        try {
            ['$statusFilter', '$billsecMin', '$callerType', '$department', '$dstNumbers'].forEach((key) => {
                if (callDetailRecords[key] && callDetailRecords[key].length) {
                    callDetailRecords[key].dropdown();
                }
            });
            callDetailRecords.applySavedAnalyticsToControls(callDetailRecords.loadFiltersState());
        } catch (err) {
            console.error('[CDR] filter controls init failed', err);
        }

        $('#cdr-filters-apply').on('click', (e) => {
            e.preventDefault();
            if (callDetailRecords.dataTable && callDetailRecords.dataTable.ajax) {
                callDetailRecords.dataTable.ajax.reload();
            }
        });
        $('#cdr-filters-reset').on('click', (e) => {
            e.preventDefault();
            callDetailRecords.resetAnalyticsFilters();
            if (callDetailRecords.dataTable && callDetailRecords.dataTable.ajax) {
                callDetailRecords.dataTable.search('').ajax.reload();
            }
        });
        $('#cdr-export-csv').on('click', (e) => {
            e.preventDefault();
            callDetailRecords.exportFiltered('csv');
        });
        $('#cdr-export-xls').on('click', (e) => {
            e.preventDefault();
            callDetailRecords.exportFiltered('xls');
        });

        // Listen for hash changes (when user clicks menu link while already on page)
        // WHY: Browser doesn't reload page on hash-only URL changes
        $(`a[href='${globalRootUrl}call-detail-records/index/#reset-cache']`).on('click', function(e) {
            e.preventDefault();
             // Remove hash from URL without page reload
             history.replaceState(null, null, window.location.pathname);
            
             callDetailRecords.clearFiltersState();
             // Also clear page length preference
             localStorage.removeItem('cdrTablePageLength');
             // Reload page to apply reset
             window.location.reload();
        });

        // Fetch metadata first, then initialize DataTable with proper date range
        // WHY: Prevents double request on page load
        callDetailRecords.fetchLatestCDRDate();
    },

    /**
     * Save current filter state to sessionStorage
     * Stores date range, search text, current page, and page length
     */
    saveFiltersState() {
        try {
            // Feature detection - exit silently if sessionStorage not available
            if (typeof sessionStorage === 'undefined') {
                console.warn('[CDR] sessionStorage not available');
                return;
            }

            const state = {
                dateFrom: null,
                dateTo: null,
                searchText: '',
                currentPage: 0,
                pageLength: callDetailRecords.getPageLength(),
                disposition: callDetailRecords.getDispositionFilter(),
                billsecMin: callDetailRecords.getBillsecMinFilter(),
                callerType: callDetailRecords.getCallerTypeFilter(),
                department: callDetailRecords.getDepartmentFilter(),
                clientNumber: callDetailRecords.getClientNumberFilter(),
                dstNumbers: callDetailRecords.getDstNumbersFilter(),
                participants: callDetailRecords.getParticipantsFilter(),
            };

            // Get dates from daterangepicker instance
            const dateRangePicker = callDetailRecords.$dateRangeSelector.data('daterangepicker');
            if (dateRangePicker && dateRangePicker.startDate && dateRangePicker.endDate) {
                state.dateFrom = dateRangePicker.startDate.format('YYYY-MM-DD');
                state.dateTo = dateRangePicker.endDate.format('YYYY-MM-DD');
            }

            // Get search text from input field
            state.searchText = callDetailRecords.$globalSearch.val() || '';

            // Get current page from DataTable (if initialized)
            if (callDetailRecords.dataTable && callDetailRecords.dataTable.page) {
                const pageInfo = callDetailRecords.dataTable.page.info();
                state.currentPage = pageInfo.page;
            }

            sessionStorage.setItem(callDetailRecords.STORAGE_KEY, JSON.stringify(state));
        } catch (error) {
            console.error('[CDR] Failed to save filters to sessionStorage:', error);
        }
    },

    /**
     * Load filter state from sessionStorage
     * @returns {Object|null} Saved state object or null if not found/invalid
     */
    loadFiltersState() {
        try {
            // Feature detection - return null if sessionStorage not available
            if (typeof sessionStorage === 'undefined') {
                console.warn('[CDR] sessionStorage not available for loading');
                return null;
            }

            const rawData = sessionStorage.getItem(callDetailRecords.STORAGE_KEY);
            if (!rawData) {
                return null;
            }

            const state = JSON.parse(rawData);

            // Validate state structure
            if (!state || typeof state !== 'object') {
                callDetailRecords.clearFiltersState();
                return null;
            }

            return state;
        } catch (error) {
            console.error('[CDR] Failed to load filters from sessionStorage:', error);
            // Clear corrupted data
            callDetailRecords.clearFiltersState();
            return null;
        }
    },

    /**
     * Clear saved filter state from sessionStorage
     */
    clearFiltersState() {
        try {
            if (typeof sessionStorage !== 'undefined') {
                sessionStorage.removeItem(callDetailRecords.STORAGE_KEY);
            }
        } catch (error) {
            console.error('Failed to clear CDR filters from sessionStorage:', error);
        }
    },

    /**
     * Initialize DataTable and event handlers
     * Called after metadata is received
     */
    initializeDataTableAndHandlers() {
        // Avoid double-init crash
        if ($.fn.dataTable && $.fn.dataTable.isDataTable('#cdr-table')) {
            callDetailRecords.$cdrTable.DataTable().clear().destroy();
            callDetailRecords.$cdrTable.find('tbody').empty();
        }

        // Initialize debounce timer variable
        let searchDebounceTimer = null;

        callDetailRecords.$globalSearch.on('keyup', (e) => {
            // Clear previous timer if the user is still typing
            clearTimeout(searchDebounceTimer);

            // Set a new timer for delayed execution
            searchDebounceTimer = setTimeout(() => {
                if (e.keyCode === 13
                    || e.keyCode === 8
                    || callDetailRecords.$globalSearch.val().length === 0) {
                    // Only pass the search keyword, dates are handled separately
                    const text = callDetailRecords.$globalSearch.val();
                    callDetailRecords.applyFilter(text);
                }
            }, 500); // 500ms delay before executing the search
        });

        // Build columns dynamically based on ACL permissions
        // WHY: Volt template conditionally renders delete column header based on isAllowed('save')
        // 'save' is a virtual permission that includes delete capability in ModuleUsersUI
        // If columns config doesn't match <thead> count, DataTables throws 'style' undefined error
        const canDelete = typeof ACLHelper !== 'undefined' && ACLHelper.isAllowed('save');
        const columns = [
            { data: 0 },                       // 0: date
            { data: 1 },                       // 1: src_num (Кто)
            { data: 2 },                       // 2: dst_num
            { data: 3 },                       // 3: department
            { data: 4 },                       // 4: status
            { data: 5 },                       // 5: wait (ring)
            { data: 6 },                       // 6: talk (billsec)
        ];
        if (canDelete) {
            columns.push({ data: null, orderable: false });  // 7: actions
        }

        callDetailRecords.$cdrTable.dataTable({
            search: {
                search: callDetailRecords.$globalSearch.val(),
            },
            serverSide: true,
            processing: true,
            columns: columns,
            columnDefs: [
                { defaultContent: "-",  targets: "_all"},
            ],
            ajax: {
                url: '/pbxcore/api/v3/cdr',
                type: 'GET',  // REST API uses GET for list retrieval
                data: function(d) {
                    const params = {};
                    let isLinkedIdSearch = false;

                    // 1. Always get dates from date range selector using daterangepicker API
                    const dateRangePicker = callDetailRecords.$dateRangeSelector.data('daterangepicker');
                    if (dateRangePicker) {
                        const startDate = dateRangePicker.startDate;
                        const endDate = dateRangePicker.endDate;

                        if (startDate && startDate.isValid() && endDate && endDate.isValid()) {
                            params.dateFrom = startDate.format('YYYY-MM-DD');
                            params.dateTo = endDate.endOf('day').format('YYYY-MM-DD HH:mm:ss');
                        }
                    }
                    // Fallback if picker not ready yet
                    if (!params.dateFrom || !params.dateTo) {
                        params.dateFrom = moment().format('YYYY-MM-DD');
                        params.dateTo = moment().endOf('day').format('YYYY-MM-DD HH:mm:ss');
                    }

                    // 2. Process search keyword from search input field
                    const searchKeyword = d.search.value || '';

                    if (searchKeyword.trim()) {
                        const keyword = searchKeyword.trim();

                        // Parse search prefixes: src:, dst:, did:, linkedid:
                        if (keyword.startsWith('src:')) {
                            // Search by source number only
                            params.src_num = keyword.substring(4).trim();
                        } else if (keyword.startsWith('dst:')) {
                            // Search by destination number only
                            params.dst_num = keyword.substring(4).trim();
                        } else if (keyword.startsWith('did:')) {
                            // Search by DID only
                            params.did = keyword.substring(4).trim();
                        } else if (keyword.startsWith('linkedid:')) {
                            // Search by linkedid - ignore date range for linkedid search
                            params.linkedid = keyword.substring(9).trim();
                            isLinkedIdSearch = true;
                            // Remove date params for linkedid search
                            delete params.dateFrom;
                            delete params.dateTo;
                        } else {
                            // Full-text search: search in src_num, dst_num, and DID
                            // WHY: User expects search without prefix to find number anywhere
                            params.search = keyword;
                        }
                    }

                    // Analytics filters
                    Object.assign(params, callDetailRecords.buildAnalyticsApiParams());

                    // REST API pagination parameters
                    params.limit = d.length;
                    params.offset = d.start;
                    params.sort = 'start';  // Sort by call start time for chronological order
                    params.order = 'DESC';

                    // WHY: WebUI always needs grouped records (by linkedid) for proper display
                    // Backend defaults to grouped=true, but explicit is better than implicit
                    params.grouped = true;

                    return params;
                },
                dataSrc: function(json) {
                    // API returns PBXApiResult structure:
                    // {result: true, data: {records: [...], pagination: {...}, departments: [...]}}
                    if (json.result && json.data) {
                        // Extract records and pagination from nested data object
                        const restData = json.data.records || [];
                        const pagination = json.data.pagination || {};

                        // Populate «Отдел» filter from ModuleUsersGroups (+ queues)
                        if (Array.isArray(json.data.departments)) {
                            callDetailRecords.fillDepartmentFilter(json.data.departments);
                        }

                        // Set DataTables pagination properties
                        json.recordsTotal = pagination.total || 0;
                        json.recordsFiltered = pagination.total || 0;

                        // Transform REST records to DataTable rows
                        return callDetailRecords.transformRestToDataTable(restData);
                    }
                    return [];
                },
                beforeSend: function(xhr) {
                    // Add Bearer token for API authentication
                    if (typeof TokenManager !== 'undefined' && TokenManager.accessToken) {
                        xhr.setRequestHeader('Authorization', `Bearer ${TokenManager.accessToken}`);
                    }
                }
            },
            paging: true,
            //scrollY: $(window).height() - callDetailRecords.$cdrTable.offset().top-150,
            sDom: 'rtip',
            deferRender: true,
            pageLength: callDetailRecords.getPageLength(),
            language: {
                ...((typeof SemanticLocalization !== 'undefined'
                    && SemanticLocalization.dataTableLocalisation)
                    ? SemanticLocalization.dataTableLocalisation
                    : {}),
                emptyTable: callDetailRecords.getEmptyTableMessage(),
                zeroRecords: callDetailRecords.getEmptyTableMessage()
            },

            /**
             * Constructs the CDR row.
             * @param {HTMLElement} row - The row element.
             * @param {Array} data - The row data.
             */
            createdRow(row, data) {
                $('td', row).eq(0).html(SecurityUtils.escapeHtml(data[0]));
                $('td', row).eq(1)
                    .html(SecurityUtils.escapeHtml(data[1]))
                    .addClass('need-update')
                    .attr('data-cdr-name', data[9] || '');
                $('td', row).eq(2)
                    .html(SecurityUtils.escapeHtml(data[2]))
                    .addClass('need-update')
                    .attr('data-cdr-name', data[10] || '');

                // Department — compact: name only (+ short agent line); full text in title
                const deptRaw = String(data[3] || '—');
                const deptParts = deptRaw.split(/\s*[·]\s*/);
                const deptName = (deptParts[0] || '—').trim() || '—';
                const deptSub = (deptParts.slice(1).join(' · ') || '').trim();
                // Exact ModuleUsersGroups name (same as «Управление телефонными группами»)
                const deptShort = deptName;
                let deptHtml = `<span class="ss-dept">${SecurityUtils.escapeHtml(deptShort)}</span>`;
                if (deptSub) {
                    const subShort = deptSub
                        .replace(/^пропустил\s+(\d+)\b.*$/i, 'проп. $1')
                        .replace(/^ответил\s+(\d+)\b.*$/i, 'отв. $1');
                    deptHtml += `<span class="ss-dept-sub">${SecurityUtils.escapeHtml(subShort)}</span>`;
                }
                $('td', row).eq(3)
                    .attr('title', deptRaw)
                    .html(deptHtml);

                const $from = $('td', row).eq(1);
                const $to = $('td', row).eq(2);
                $from.attr('title', $from.text());
                $to.attr('title', $to.text());

                // Status badge
                const dispRaw = String(data[8] || '').toUpperCase().replace(/\s+/g, '');
                const statusText = SecurityUtils.escapeHtml(data[4] || '—');
                let statusMod = 'muted';
                if (dispRaw === 'ANSWERED' || dispRaw === 'ANSWER') statusMod = 'ok';
                else if (dispRaw === 'NOANSWER' || dispRaw === 'CANCEL') statusMod = 'miss';
                else if (dispRaw === 'BUSY' || dispRaw === 'FAILED' || dispRaw === 'CHANUNAVAIL') statusMod = 'bad';
                $('td', row).eq(4).html(`<span class="ss-status ss-status-${statusMod}">${statusText}</span>`);
                $('td', row).eq(5).html(SecurityUtils.escapeHtml(data[5] || '—')).addClass('right aligned ss-mono');
                $('td', row).eq(6).html(SecurityUtils.escapeHtml(data[6] || '—')).addClass('right aligned ss-mono');

                if (!canDelete) {
                    return;
                }

                let actionsHtml = '<span class="ss-cdr-row-actions">';

                const canViewLogs = typeof ACLHelper !== 'undefined' && ACLHelper.isAllowed('viewSystemDiagnostic');
                if (canViewLogs && data.ids !== '') {
                    actionsHtml += `<i data-ids="${SecurityUtils.escapeHtml(data.ids)}" class="file alternate outline icon" style="cursor:pointer;" title="Лог"></i>`;
                }

                actionsHtml += `<a href="#" class="two-steps-delete delete-record"
                                   data-record-id="${SecurityUtils.escapeHtml(data.DT_RowId)}"
                                   title="${SecurityUtils.escapeHtml(globalTranslate.cdr_DeleteRecord || 'Удалить')}">
                                   <i class="icon trash red"></i>
                                </a>`;
                actionsHtml += '</span>';

                $('td', row).eq(7).html(actionsHtml).addClass('right aligned ss-cdr-actions-cell');
            },

            /**
             * Draw event - fired once the table has completed a draw.
             */
            drawCallback() {
                ExtensionsAPI.updatePhonesRepresent('need-update');
                callDetailRecords.togglePaginationControls();
                const api = callDetailRecords.$cdrTable.DataTable();
                const empty = !api || api.rows({ page: 'current' }).data().length === 0;
                const $empty = $('#cdr-empty-state');
                const $card = $('#cdr-table-card');
                if ($empty.length) {
                    $empty.toggle(empty);
                    $card.toggleClass('is-empty', empty);
                }
                // Refresh titles after name enrichment (long text → tooltip)
                callDetailRecords.$cdrTable.find('tbody tr').each(function refreshTitles() {
                    const $tds = $(this).children('td');
                    [$tds.eq(1), $tds.eq(2), $tds.eq(3)].forEach(($td) => {
                        if ($td.length) {
                            $td.attr('title', ($td.text() || '').trim());
                        }
                    });
                });
                // Move DataTables pager into our footer slot
                const $slot = $('#cdr-pager-slot');
                const $paginate = $(api.table().container()).find('.dataTables_paginate');
                const $info = $(api.table().container()).find('.dataTables_info');
                if ($slot.length && $paginate.length) {
                    $slot.empty().append($info).append($paginate);
                }
            },
            /**
             * Initialization complete callback - fired after first data load
             * WHY: Restore filters AFTER DataTable has loaded initial data from server
             */
            initComplete() {
                // Set flag FIRST to allow state saving during filter restoration
                callDetailRecords.isInitialized = true;
                // Now restore filters - draw event will correctly save the restored state
                callDetailRecords.restoreFiltersFromState();
            },
            ordering: false,
        });
        callDetailRecords.dataTable = callDetailRecords.$cdrTable.DataTable();

        // Initialize the Search component AFTER DataTable is created (if search UI exists)
        if (callDetailRecords.$searchCDRInput.length && $('#search-icon').length) {
            callDetailRecords.$searchCDRInput.search({
                minCharacters: 0,
                searchOnFocus: false,
                searchFields: ['title'],
                showNoResults: false,
                source: [
                    { title: globalTranslate.cdr_SearchBySourceNumber, value: 'src:' },
                    { title: globalTranslate.cdr_SearchByDestNumber, value: 'dst:' },
                    { title: globalTranslate.cdr_SearchByDID, value: 'did:' },
                    { title: globalTranslate.cdr_SearchByLinkedID, value: 'linkedid:' },
                    { title: globalTranslate.cdr_SearchByCustomPhrase, value: '' },
                ],
                onSelect: function(result, response) {
                    callDetailRecords.$globalSearch.val(result.value);
                    callDetailRecords.$searchCDRInput.search('hide results');
                    return false;
                }
            });

            // Start the search when you click on the icon
            $('#search-icon').on('click', function() {
                callDetailRecords.$globalSearch.focus();
                callDetailRecords.$searchCDRInput.search('query');
            });
        }

        // Event listener to save the user's page length selection and update the table
        callDetailRecords.$pageLengthSelector.dropdown({
            onChange(pageLength) {
                if (pageLength === 'auto') {
                    pageLength = callDetailRecords.calculatePageLength();
                    localStorage.removeItem('cdrTablePageLength');
                } else {
                    localStorage.setItem('cdrTablePageLength', pageLength);
                }
                callDetailRecords.dataTable.page.len(pageLength).draw();
            },
        });
        callDetailRecords.$pageLengthSelector.on('click', function(event) {
            event.stopPropagation(); // Prevent the event from bubbling
        });

        // Set the select input value to the saved value if it exists
        const savedPageLength = localStorage.getItem('cdrTablePageLength');
        if (savedPageLength) {
            callDetailRecords.$pageLengthSelector.dropdown('set value', savedPageLength);
        }

        callDetailRecords.dataTable.on('draw', () => {
            callDetailRecords.$globalSearch.closest('div').removeClass('loading');

            // Skip saving state during initial load before filters are restored
            if (!callDetailRecords.isInitialized) {
                return;
            }

            // Save state after every draw (pagination, search, date change)
            callDetailRecords.saveFiltersState();
        });

        // Add event listener for clicking on icon with data-ids (open in new window)
        callDetailRecords.$cdrTable.on('click', '[data-ids]', (e) => {
            e.preventDefault();
            e.stopPropagation();

            const ids = $(e.currentTarget).attr('data-ids');
            if (ids !== undefined && ids !== '') {
                const url = `${globalRootUrl}system-diagnostic/index/?filter=${encodeURIComponent(ids)}#file=asterisk%2Fverbose`;
                window.open(url, '_blank');
            }
        });

        // Handle second click on delete button (after two-steps-delete changes icon to close)
        // WHY: Two-steps-delete mechanism prevents accidental deletion
        // First click: trash → close (by delete-something.js), Second click: execute deletion
        callDetailRecords.$cdrTable.on('click', 'a.delete-record:not(.two-steps-delete)', (e) => {
            e.preventDefault();
            e.stopPropagation(); // Prevent row expansion

            const $button = $(e.currentTarget);
            const recordId = $button.attr('data-record-id');

            if (!recordId) {
                return;
            }

            // Add loading state
            $button.addClass('disabled loading');

            // Always delete with recordings and linked records
            callDetailRecords.deleteRecord(recordId, $button);
        });
    },

    /**
     * Restore filters from saved state after DataTable initialization
     * WHY: Must be called after DataTable is created to restore search and page
     */
    restoreFiltersFromState() {
        const savedState = callDetailRecords.loadFiltersState();
        if (!savedState) {
            return;
        }

        callDetailRecords.applySavedAnalyticsToControls(savedState);

        // Restore search text to input field
        if (savedState.searchText && callDetailRecords.$globalSearch.length) {
            callDetailRecords.$globalSearch.val(savedState.searchText);
            callDetailRecords.dataTable.search(savedState.searchText);
        }

        if (savedState.currentPage) {
            setTimeout(() => {
                callDetailRecords.dataTable.page(savedState.currentPage).draw(false);
            }, 100);
        } else {
            callDetailRecords.dataTable.ajax.reload(null, false);
        }
    },

    applySavedAnalyticsToControls(savedState) {
        if (!savedState) {
            if (callDetailRecords.$billsecMin && callDetailRecords.$billsecMin.length) {
                callDetailRecords.$billsecMin.dropdown('set selected', String(callDetailRecords.DEFAULT_BILLSEC_MIN));
            }
            return;
        }
        if (savedState.disposition && callDetailRecords.$statusFilter.length) {
            callDetailRecords.$statusFilter.dropdown('set selected', savedState.disposition);
        }
        if (savedState.billsecMin !== undefined && savedState.billsecMin !== null && callDetailRecords.$billsecMin.length) {
            callDetailRecords.$billsecMin.dropdown('set selected', String(savedState.billsecMin));
        }
        if (savedState.callerType && callDetailRecords.$callerType.length) {
            callDetailRecords.$callerType.dropdown('set selected', savedState.callerType);
        }
        if (savedState.department && callDetailRecords.$department.length) {
            callDetailRecords.$department.dropdown('set selected', savedState.department);
        }
        if (savedState.clientNumber !== undefined && callDetailRecords.$clientNumber.length) {
            callDetailRecords.$clientNumber.val(savedState.clientNumber || '');
        }
        if (savedState.participants !== undefined && callDetailRecords.$participants.length) {
            callDetailRecords.$participants.val(savedState.participants || '');
        }
        if (savedState.dstNumbers && callDetailRecords.$dstNumbers.length) {
            const val = Array.isArray(savedState.dstNumbers)
                ? (savedState.dstNumbers[0] || 'any')
                : String(savedState.dstNumbers).split(',')[0] || 'any';
            callDetailRecords.$dstNumbers.dropdown('set selected', val || 'any');
        }
    },

    resetAnalyticsFilters() {
        if (callDetailRecords.$statusFilter.length) {
            callDetailRecords.$statusFilter.dropdown('set selected', 'ALL');
        }
        if (callDetailRecords.$billsecMin.length) {
            callDetailRecords.$billsecMin.dropdown('set selected', String(callDetailRecords.DEFAULT_BILLSEC_MIN));
        }
        if (callDetailRecords.$callerType.length) {
            callDetailRecords.$callerType.dropdown('set selected', 'any');
        }
        if (callDetailRecords.$department && callDetailRecords.$department.length) {
            callDetailRecords.$department.dropdown('set selected', 'any');
        }
        if (callDetailRecords.$clientNumber.length) {
            callDetailRecords.$clientNumber.val('');
        }
        if (callDetailRecords.$participants.length) {
            callDetailRecords.$participants.val('');
        }
        if (callDetailRecords.$dstNumbers.length) {
            callDetailRecords.$dstNumbers.dropdown('set selected', 'any');
        }
        if (callDetailRecords.$globalSearch.length) {
            callDetailRecords.$globalSearch.val('');
        }
        callDetailRecords.clearFiltersState();
    },

    buildAnalyticsApiParams() {
        const params = {};
        const disposition = callDetailRecords.getDispositionFilter();
        if (disposition && disposition !== 'ALL') {
            params.disposition = disposition;
        }
        const billsecMin = callDetailRecords.getBillsecMinFilter();
        if (billsecMin > 0) {
            params.billsecMin = billsecMin;
        }
        const callerType = callDetailRecords.getCallerTypeFilter();
        if (callerType && callerType !== 'any') {
            params.callerType = callerType;
        }
        const department = callDetailRecords.getDepartmentFilter();
        if (department && department !== 'any') {
            params.department = department;
        }
        const clientNumber = callDetailRecords.getClientNumberFilter();
        if (clientNumber) {
            params.clientNumber = clientNumber;
        }
        const dstNumbers = callDetailRecords.getDstNumbersFilter();
        if (dstNumbers.length) {
            params.dstNumbers = dstNumbers.join(',');
        }
        const participants = callDetailRecords.getParticipantsFilter();
        if (participants) {
            params.participants = participants;
        }
        return params;
    },

    getDispositionFilter() {
        if (!callDetailRecords.$statusFilter || !callDetailRecords.$statusFilter.length) {
            return 'ALL';
        }
        const val = callDetailRecords.$statusFilter.dropdown('get value');
        return (val || 'ALL').toString();
    },

    getBillsecMinFilter() {
        if (!callDetailRecords.$billsecMin || !callDetailRecords.$billsecMin.length) {
            return callDetailRecords.DEFAULT_BILLSEC_MIN;
        }
        const raw = callDetailRecords.$billsecMin.dropdown('get value');
        if (raw === '' || raw === null || raw === undefined) {
            return callDetailRecords.DEFAULT_BILLSEC_MIN;
        }
        const n = parseInt(raw, 10);
        return Number.isFinite(n) && n >= 0 ? n : callDetailRecords.DEFAULT_BILLSEC_MIN;
    },

    getCallerTypeFilter() {
        if (!callDetailRecords.$callerType || !callDetailRecords.$callerType.length) {
            return 'any';
        }
        return (callDetailRecords.$callerType.dropdown('get value') || 'any').toString();
    },

    getDepartmentFilter() {
        if (!callDetailRecords.$department || !callDetailRecords.$department.length) {
            return 'any';
        }
        return (callDetailRecords.$department.dropdown('get value') || 'any').toString();
    },

    /**
     * Fill department dropdown from API (ModuleUsersGroups + queues).
     * @param {Array<{value:string,label:string}>} departments
     */
    fillDepartmentFilter(departments) {
        if (!callDetailRecords.$department || !callDetailRecords.$department.length) {
            return;
        }
        if (callDetailRecords._deptFilterReady) {
            return;
        }
        const current = callDetailRecords.$department.dropdown('get value') || 'any';
        const $menu = callDetailRecords.$department.find('.menu');
        $menu.empty();
        $menu.append('<div class="item" data-value="any">Все отделы</div>');
        (departments || []).forEach((d) => {
            if (!d || !d.value) return;
            const label = SecurityUtils.escapeHtml(d.label || d.value);
            const value = SecurityUtils.escapeHtml(String(d.value));
            $menu.append(`<div class="item" data-value="${value}">${label}</div>`);
        });
        try {
            callDetailRecords.$department.dropdown('refresh');
            callDetailRecords.$department.dropdown('set selected', current || 'any');
        } catch (e) {
            // ignore
        }
        callDetailRecords._deptFilterReady = true;
    },

    getClientNumberFilter() {
        if (!callDetailRecords.$clientNumber || !callDetailRecords.$clientNumber.length) {
            return '';
        }
        return String(callDetailRecords.$clientNumber.val() || '').trim();
    },

    getDstNumbersFilter() {
        if (!callDetailRecords.$dstNumbers || !callDetailRecords.$dstNumbers.length) {
            return [];
        }
        const raw = callDetailRecords.$dstNumbers.dropdown('get value');
        const val = Array.isArray(raw) ? (raw[0] || '') : String(raw || '').trim();
        if (!val || val === 'any' || val === '__ALL__') {
            return [];
        }
        return [val];
    },

    getParticipantsFilter() {
        if (!callDetailRecords.$participants || !callDetailRecords.$participants.length) {
            return '';
        }
        return String(callDetailRecords.$participants.val() || '').trim();
    },

    /**
     * Collect current date + analytics filter params for API
     */
    buildListRequestParams(extra = {}) {
        const params = {
            limit: 1000,
            offset: 0,
            sort: 'start',
            order: 'DESC',
            grouped: true,
            ...callDetailRecords.buildAnalyticsApiParams(),
            ...extra,
        };
        const dateRangePicker = callDetailRecords.$dateRangeSelector
            && callDetailRecords.$dateRangeSelector.data('daterangepicker');
        if (dateRangePicker) {
            const startDate = dateRangePicker.startDate;
            const endDate = dateRangePicker.endDate;
            if (startDate && startDate.isValid() && endDate && endDate.isValid()) {
                params.dateFrom = startDate.format('YYYY-MM-DD');
                params.dateTo = endDate.endOf('day').format('YYYY-MM-DD HH:mm:ss');
            }
        }
        return params;
    },

    /**
     * Export currently filtered CDR rows as CSV or Excel XML
     * @param {'csv'|'xls'} format
     */
    exportFiltered(format) {
        const $btn = format === 'xls' ? $('#cdr-export-xls') : $('#cdr-export-csv');
        $btn.addClass('loading disabled');

        const params = callDetailRecords.buildListRequestParams();
        const headers = {};
        if (typeof TokenManager !== 'undefined' && TokenManager.accessToken) {
            headers.Authorization = `Bearer ${TokenManager.accessToken}`;
        }

        $.ajax({
            url: '/pbxcore/api/v3/cdr',
            type: 'GET',
            data: params,
            headers,
            dataType: 'json',
        }).done((json) => {
            const groups = (json && json.result && json.data && json.data.records)
                ? json.data.records
                : [];
            if (!groups.length) {
                if (typeof UserMessage !== 'undefined') {
                    UserMessage.showInformation('Нет данных для выгрузки по текущим фильтрам');
                }
                return;
            }
            const rows = callDetailRecords.groupsToExportRows(groups);
            if (format === 'xls') {
                callDetailRecords.downloadXls(rows, 'call-history.xls');
            } else {
                callDetailRecords.downloadCsv(rows, 'call-history.csv');
            }
        }).fail(() => {
            if (typeof UserMessage !== 'undefined') {
                UserMessage.showError('Не удалось выгрузить данные');
            }
        }).always(() => {
            $btn.removeClass('loading disabled');
        });
    },

    groupsToExportRows(groups) {
        const statusMap = {
            ANSWERED: 'Отвечен',
            ANSWER: 'Отвечен',
            NOANSWER: 'Пропущен',
            BUSY: 'Занято',
            FAILED: 'Ошибка',
            CHANUNAVAIL: 'Недоступен',
            CANCEL: 'Отменён',
        };
        const fmt = (sec) => {
            const s = Math.max(0, parseInt(sec, 10) || 0);
            if (!s) return '';
            const mm = String(Math.floor(s / 60)).padStart(2, '0');
            const ss = String(s % 60).padStart(2, '0');
            return `${mm}:${ss}`;
        };
        return groups.map((g) => {
            const billsec = g.totalBillsec || 0;
            const duration = g.totalDuration || 0;
            const wait = Math.max(0, duration - billsec);
            const disp = String(g.disposition || '').toUpperCase().replace(/\s+/g, '');
            return {
                'Дата': g.start || '',
                'Кто': [g.src_name, g.src_num].filter(Boolean).join(' '),
                'Кому': [g.dst_name, g.dst_num || g.did].filter(Boolean).join(' '),
                'Отдел': g.department || '',
                'Сотрудник': g.agentName || g.agentExt || '',
                'Роль': g.agentRole === 'answered' ? 'ответил' : (g.agentRole === 'missed' ? 'пропустил' : ''),
                'Статус': statusMap[disp] || g.disposition || '',
                'Ожидание сек': wait,
                'Разговор сек': billsec,
                'Ожидание': fmt(wait),
                'Разговор': fmt(billsec),
                'linkedid': g.linkedid || '',
            };
        });
    },

    downloadCsv(rows, filename) {
        const cols = Object.keys(rows[0]);
        const esc = (v) => `"${String(v ?? '').replace(/"/g, '""')}"`;
        const lines = [cols.map(esc).join(';')];
        rows.forEach((r) => {
            lines.push(cols.map((c) => esc(r[c])).join(';'));
        });
        const blob = new Blob(['\ufeff' + lines.join('\n')], { type: 'text/csv;charset=utf-8;' });
        callDetailRecords.triggerDownload(blob, filename);
    },

    downloadXls(rows, filename) {
        const cols = Object.keys(rows[0]);
        const escXml = (v) => String(v ?? '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;');
        let xml = '<?xml version="1.0"?><?mso-application progid="Excel.Sheet"?>';
        xml += '<Workbook xmlns="urn:schemas-microsoft-com:office:spreadsheet" '
            + 'xmlns:ss="urn:schemas-microsoft-com:office:spreadsheet"><Worksheet ss:Name="CDR"><Table>';
        xml += '<Row>' + cols.map((c) => `<Cell><Data ss:Type="String">${escXml(c)}</Data></Cell>`).join('') + '</Row>';
        rows.forEach((r) => {
            xml += '<Row>' + cols.map((c) => {
                const val = r[c];
                const isNum = typeof val === 'number';
                return `<Cell><Data ss:Type="${isNum ? 'Number' : 'String'}">${escXml(val)}</Data></Cell>`;
            }).join('') + '</Row>';
        });
        xml += '</Table></Worksheet></Workbook>';
        const blob = new Blob([xml], { type: 'application/vnd.ms-excel' });
        callDetailRecords.triggerDownload(blob, filename);
    },

    triggerDownload(blob, filename) {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        setTimeout(() => {
            URL.revokeObjectURL(url);
            a.remove();
        }, 500);
    },

    /**
     * Delete CDR record via REST API
     * WHY: Deletes by linkedid - automatically removes entire conversation with all linked records
     * @param {string} recordId - CDR linkedid (like "mikopbx-1760784793.4627")
     * @param {jQuery} $button - Button element to update state
     */
    deleteRecord(recordId, $button) {
        // Always delete with recording files
        // WHY: linkedid automatically deletes all linked records (no deleteLinked parameter needed)
        CdrAPI.deleteRecord(recordId, { deleteRecording: true }, (response) => {
            $button.removeClass('loading disabled');

            if (response && response.result === true) {
                // Silently reload the DataTable to reflect changes
                // WHY: Visual feedback (disappearing row) is enough, no need for success toast
                callDetailRecords.dataTable.ajax.reload(null, false);
            } else {
                // Show error message only on failure
                const errorMsg = response?.messages?.error?.[0] ||
                                globalTranslate.cdr_DeleteFailed ||
                                'Failed to delete record';
                UserMessage.showError(errorMsg);
            }
        });
    },

    /**
     * Toggles the pagination controls visibility based on data size
     */
    togglePaginationControls() {
        const info = callDetailRecords.dataTable.page.info();
        if (info.pages <= 1) {
            $(callDetailRecords.dataTable.table().container()).find('.dataTables_paginate').hide();
        } else {
            $(callDetailRecords.dataTable.table().container()).find('.dataTables_paginate').show();
        }
    },

    /**
     * Normalize a date value to a valid moment (day bounds).
     */
    toValidMoment(value, fallback) {
        const m = value ? moment(value) : null;
        if (m && m.isValid()) {
            return m;
        }
        return fallback.clone();
    },

    /**
     * Resolve start/end dates for calendar + first AJAX request.
     */
    resolveBootDates(savedState, meta) {
        const todayStart = moment().startOf('day');
        const todayEnd = moment().endOf('day');
        let startDate = todayStart.clone();
        let endDate = todayEnd.clone();

        if (savedState && savedState.dateFrom && savedState.dateTo) {
            startDate = callDetailRecords.toValidMoment(savedState.dateFrom, todayStart).startOf('day');
            endDate = callDetailRecords.toValidMoment(savedState.dateTo, todayEnd).endOf('day');
        } else if (meta && meta.hasRecords) {
            startDate = callDetailRecords.toValidMoment(meta.earliestDate, todayStart).startOf('day');
            endDate = callDetailRecords.toValidMoment(meta.latestDate, todayEnd).endOf('day');
        }

        if (endDate.isBefore(startDate)) {
            startDate = todayStart.clone();
            endDate = todayEnd.clone();
        }

        // Never ask picker for a day after "today"
        if (endDate.isAfter(todayEnd)) {
            endDate = todayEnd.clone();
        }
        if (startDate.isAfter(todayEnd)) {
            startDate = todayStart.clone();
        }

        return { startDate, endDate };
    },

    /**
     * Fetches CDR metadata (date range) using CdrAPI
     * WHY: Lightweight request returns only metadata (dates), not full CDR records
     * Avoids double request on page load
     *
     * IMPORTANT: boot UI immediately — never leave calendar/table waiting on metadata.
     */
    fetchLatestCDRDate() {
        const savedState = callDetailRecords.loadFiltersState();
        let booted = false;

        const bootUi = (startDate, endDate) => {
            if (booted) {
                return;
            }
            booted = true;

            const dates = callDetailRecords.resolveBootDates(
                null,
                { hasRecords: true, earliestDate: startDate, latestDate: endDate },
            );

            callDetailRecords.hasCDRRecords = true;
            $('#cdr-filters-panel').show();
            callDetailRecords.$cdrTable.show();
            callDetailRecords.$emptyDatabasePlaceholder.hide();

            try {
                callDetailRecords.initializeDateRangeSelector(dates.startDate, dates.endDate);
            } catch (err) {
                console.error('[CDR] daterangepicker init failed', err);
            }

            // Always force visible value (daterangepicker may leave placeholder on bad locale/maxDate)
            if (callDetailRecords.$dateRangeSelector && callDetailRecords.$dateRangeSelector.length) {
                const label = `${dates.startDate.format('DD/MM/YYYY')} - ${dates.endDate.format('DD/MM/YYYY')}`;
                callDetailRecords.$dateRangeSelector.val(label);
            }

            // Open calendar by icon click
            $('#cdr-filters-panel .ss-field-period .icon').off('click.cdrCal').on('click.cdrCal', () => {
                callDetailRecords.$dateRangeSelector.focus().trigger('click');
            });

            try {
                callDetailRecords.initializeDataTableAndHandlers();
            } catch (err) {
                console.error('[CDR] DataTable init failed', err);
            }
        };

        // Boot immediately with saved/today dates — do not wait for metadata
        const immediate = callDetailRecords.resolveBootDates(savedState, null);
        bootUi(immediate.startDate, immediate.endDate);

        // Optionally widen range from metadata once it arrives (before user interacts)
        if (typeof CdrAPI === 'undefined' || typeof CdrAPI.getMetadata !== 'function') {
            return;
        }

        try {
            CdrAPI.getMetadata({ limit: 100 }, (data) => {
                if (!data || !data.hasRecords) {
                    return;
                }
                // Keep user-saved period; only adopt metadata range when none saved
                if (savedState && savedState.dateFrom && savedState.dateTo) {
                    return;
                }
                const fromMeta = callDetailRecords.resolveBootDates(null, data);
                const picker = callDetailRecords.$dateRangeSelector.data('daterangepicker');
                if (picker && typeof picker.setStartDate === 'function') {
                    picker.setStartDate(fromMeta.startDate);
                    picker.setEndDate(fromMeta.endDate);
                    callDetailRecords.$dateRangeSelector.val(
                        `${fromMeta.startDate.format('DD/MM/YYYY')} - ${fromMeta.endDate.format('DD/MM/YYYY')}`,
                    );
                    if (callDetailRecords.dataTable && callDetailRecords.dataTable.ajax) {
                        callDetailRecords.dataTable.ajax.reload();
                    }
                }
            });
        } catch (err) {
            console.warn('[CDR] getMetadata failed', err);
        }
    },

    /**
     * Gets a styled empty table message
     * @returns {string} HTML message for empty table
     */
    getEmptyTableMessage() {
        // If database is empty, we don't show this message in table
        if (!callDetailRecords.hasCDRRecords) {
            return '';
        }
        
        // Show filtered empty state message
        return `
        <div class="ui placeholder segment">
            <div class="ui icon header">
                <i class="search icon"></i>
                ${globalTranslate.cdr_FilteredEmptyTitle}
            </div>
            <div class="inline">
                <div class="ui text">
                    ${globalTranslate.cdr_FilteredEmptyDescription}
                </div>
            </div>
        </div>`;
    },
    
    /**
     * Shows the empty database placeholder and hides the table
     */
    showEmptyDatabasePlaceholder() {
        // Hide the table itself (DataTable won't be initialized)
        callDetailRecords.$cdrTable.hide();

        // Hide filter panel when database is empty
        $('#cdr-filters-panel').hide();

        // Show placeholder
        callDetailRecords.$emptyDatabasePlaceholder.show();
    },

    /**
     * Transform REST API grouped records to DataTable row format
     * @param {Array} restData - Array of grouped CDR records from REST API
     * @returns {Array} Array of DataTable rows
     */
    transformRestToDataTable(restData) {
        return restData.map(group => {
            // Talk = billsec; Wait = ring time (duration - billsec), or full duration if not answered
            const billsec = group.totalBillsec || 0;
            const duration = group.totalDuration || 0;
            const waitSec = Math.max(0, duration - billsec);
            const formatSec = (sec) => {
                if (!sec || sec <= 0) return '—';
                const fmt = sec < 3600 ? 'mm:ss' : 'HH:mm:ss';
                return moment.utc(sec * 1000).format(fmt);
            };
            const waitTiming = formatSec(waitSec);
            const talkTiming = formatSec(billsec);
            const disposition = (group.disposition || '').toUpperCase().replace(/\s+/g, '');
            const statusMap = {
                ANSWERED: 'Отвечен',
                ANSWER: 'Отвечен',
                NOANSWER: 'Пропущен',
                BUSY: 'Занято',
                FAILED: 'Ошибка',
                CHANUNAVAIL: 'Недоступен',
                CANCEL: 'Отменён',
            };
            const statusLabel = statusMap[disposition] || (group.disposition || '—');
            const departmentLabel = group.departmentLabel
                || group.department
                || '—';

            // Format start date
            const formattedDate = moment(group.start).format('DD-MM-YYYY HH:mm:ss');

            // Extract recording records - filter only records with actual recording files
            const recordings = (group.records || [])
                .filter(r => r.recordingfile && r.recordingfile.length > 0)
                .map(r => ({
                    id: r.id,
                    src_num: r.src_num,
                    src_name: r.src_name || '',
                    dst_num: r.dst_num,
                    dst_name: r.dst_name || '',
                    recordingfile: r.recordingfile,
                    playback_url: r.playback_url,   // Token-based URL for playback
                    download_url: r.download_url    // Token-based URL for download
                }));

            // Determine CSS class
            const hasRecordings = recordings.length > 0;
            // No expand/player in this table — recordings live in Call Recordings section
            const dtRowClass = '';
            const negativeClass = '';

            // Collect unique verbose call IDs
            const ids = [...new Set(
                (group.records || [])
                    .map(r => r.verbose_call_id)
                    .filter(id => id && id.length > 0)
            )].join('&');

            // Return DataTable row format
            // DataTables needs both array indices AND special properties
            const row = [
                formattedDate,              // 0: date
                group.src_num,              // 1: source number
                group.dst_num || group.did, // 2: destination number or DID
                departmentLabel,            // 3: department + who answered/missed
                statusLabel,                // 4: status
                waitTiming,                 // 5: wait / ring
                talkTiming,                 // 6: talk
                recordings,                 // 7: recording records array
                group.disposition,          // 8: disposition raw
                group.src_name || '',       // 9: source caller name
                group.dst_name || ''        // 10: destination caller name
            ];

            // Add DataTables special properties
            row.DT_RowId = group.linkedid;
            row.DT_RowClass = dtRowClass + negativeClass;
            row.ids = ids; // Store raw IDs without encoding - encoding will be applied when building URL

            return row;
        });
    },

    /**
     * Shows a set of call records when a row is clicked.
     * @param {Array} data - The row data.
     * @returns {string} The HTML representation of the call records.
     */
    showRecords(data) {
        let htmlPlayer = '<table class="ui very basic table cdr-player"><tbody>';
        data[6].forEach((record, i) => {
            if (i > 0) {
                htmlPlayer += '<td><tr></tr></td>';
                htmlPlayer += '<td><tr></tr></td>';
            }
            if (record.recordingfile === undefined
                || record.recordingfile === null
                || record.recordingfile.length === 0) {

                htmlPlayer += `

<tr class="detail-record-row disabled" id="${record.id}">
   	<td class="one wide"></td>
   	<td class="one wide right aligned">
   		<i class="ui icon play"></i>
	   	<audio preload="metadata" id="audio-player-${record.id}" src=""></audio>
	</td>
    <td class="five wide">
    	<div class="ui range cdr-player" data-value="${record.id}"></div>
    </td>
    <td class="one wide"><span class="cdr-duration"></span></td>
    <td class="one wide">
    	<i class="ui icon download" data-value=""></i>
    </td>
    <td class="right aligned"><span class="need-update" data-cdr-name="${SecurityUtils.escapeHtml(record.src_name || '')}">${SecurityUtils.escapeHtml(record.src_num)}</span></td>
    <td class="one wide center aligned"><i class="icon exchange"></i></td>
   	<td class="left aligned"><span class="need-update" data-cdr-name="${SecurityUtils.escapeHtml(record.dst_name || '')}">${SecurityUtils.escapeHtml(record.dst_num)}</span></td>
</tr>`;
            } else {
                // Use token-based URLs instead of direct file paths
                // WHY: Security - hides actual file paths from user
                // Two separate endpoints: :playback (inline) and :download (file)
                const playbackUrl = record.playback_url || '';
                const downloadUrl = record.download_url || '';

                htmlPlayer += `

<tr class="detail-record-row" id="${record.id}">
   	<td class="one wide"></td>
   	<td class="one wide right aligned">
   		<i class="ui icon play"></i>
	   	<audio preload="metadata" id="audio-player-${record.id}" src="${playbackUrl}"></audio>
	</td>
    <td class="five wide">
    	<div class="ui range cdr-player" data-value="${record.id}"></div>
    </td>
    <td class="one wide"><span class="cdr-duration"></span></td>
    <td class="one wide">
    	<div class="ui compact icon top left pointing dropdown download-format-dropdown" data-download-url="${downloadUrl}">
    		<i class="download icon"></i>
    		<div class="menu">
    			<div class="item" data-format="webm">WebM (Opus)</div>
    			<div class="item" data-format="mp3">MP3</div>
    			<div class="item" data-format="wav">WAV</div>
    			<div class="item" data-format="ogg">OGG (Opus)</div>
    		</div>
    	</div>
    </td>
    <td class="right aligned"><span class="need-update" data-cdr-name="${SecurityUtils.escapeHtml(record.src_name || '')}">${SecurityUtils.escapeHtml(record.src_num)}</span></td>
    <td class="one wide center aligned"><i class="icon exchange"></i></td>
   	<td class="left aligned"><span class="need-update" data-cdr-name="${SecurityUtils.escapeHtml(record.dst_name || '')}">${SecurityUtils.escapeHtml(record.dst_num)}</span></td>
</tr>`;
            }
        });
        htmlPlayer += '</tbody></table>';
        return htmlPlayer;
    },

    /**
     * Gets the page length for DataTable, considering user's saved preference
     * @returns {number}
     */
    getPageLength() {
        // Get the user's saved value or use the automatically calculated value if none exists
        const savedPageLength = localStorage.getItem('cdrTablePageLength');
        return savedPageLength ? parseInt(savedPageLength, 10) : callDetailRecords.calculatePageLength();
    },

    /**
     * Calculates the number of rows that can fit on a page based on the current window height.
     * Dynamically measures the actual overhead from DOM elements instead of using a hardcoded estimate.
     * @returns {number}
     */
    calculatePageLength() {
        // Measure actual row height from rendered row, fallback to compact table default (~36px)
        let rowHeight = callDetailRecords.$cdrTable.find('tbody > tr').first().outerHeight() || 36;

        // Calculate overhead dynamically from the table's position in the page
        const windowHeight = window.innerHeight;
        let overhead = 400; // safe fallback
        const tableEl = callDetailRecords.$cdrTable.get(0);
        if (tableEl) {
            const thead = callDetailRecords.$cdrTable.find('thead');
            const theadHeight = thead.length ? thead.outerHeight() : 38;
            const tableTop = tableEl.getBoundingClientRect().top;

            // Space below: pagination(50) + info bar(30) + segment padding(14) + version footer(35) + margins(10)
            const bottomReserve = 139;

            overhead = tableTop + theadHeight + bottomReserve;
        }

        return Math.max(Math.floor((windowHeight - overhead) / rowHeight), 5);
    },
    /**
     * Initializes the date range selector.
     * @param {moment} startDate - Optional earliest record date from last 100 records
     * @param {moment} endDate - Optional latest record date from last 100 records
     */
    initializeDateRangeSelector(startDate = null, endDate = null) {
        if (!callDetailRecords.$dateRangeSelector || !callDetailRecords.$dateRangeSelector.length) {
            throw new Error('date-range-selector input not found');
        }
        if (typeof callDetailRecords.$dateRangeSelector.daterangepicker !== 'function') {
            throw new Error('daterangepicker plugin is not loaded');
        }

        const todayEnd = moment().endOf('day');
        const safeStart = callDetailRecords.toValidMoment(startDate, moment().startOf('day')).startOf('day');
        let safeEnd = callDetailRecords.toValidMoment(endDate, todayEnd).endOf('day');
        if (safeEnd.isAfter(todayEnd)) {
            safeEnd = todayEnd.clone();
        }
        if (safeEnd.isBefore(safeStart)) {
            safeEnd = safeStart.clone().endOf('day');
            if (safeEnd.isAfter(todayEnd)) {
                safeEnd = todayEnd.clone();
            }
        }

        // Prefer known-good locale arrays — broken SemanticLocalization.days breaks the picker
        const locDays = (SemanticLocalization
            && SemanticLocalization.calendarText
            && Array.isArray(SemanticLocalization.calendarText.days)
            && SemanticLocalization.calendarText.days.length >= 7)
            ? SemanticLocalization.calendarText.days
            : ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'];
        const locMonths = (SemanticLocalization
            && SemanticLocalization.calendarText
            && Array.isArray(SemanticLocalization.calendarText.months)
            && SemanticLocalization.calendarText.months.length >= 12)
            ? SemanticLocalization.calendarText.months
            : ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
                'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];

        const options = {
            ranges: {
                [(globalTranslate && globalTranslate.cal_Today) || 'Сегодня']: [moment().startOf('day'), moment().endOf('day')],
                [(globalTranslate && globalTranslate.cal_Yesterday) || 'Вчера']: [
                    moment().subtract(1, 'days').startOf('day'),
                    moment().subtract(1, 'days').endOf('day'),
                ],
                [(globalTranslate && globalTranslate.cal_LastWeek) || 'Неделя']: [
                    moment().subtract(6, 'days').startOf('day'),
                    moment().endOf('day'),
                ],
                [(globalTranslate && globalTranslate.cal_Last30Days) || '30 дней']: [
                    moment().subtract(29, 'days').startOf('day'),
                    moment().endOf('day'),
                ],
                [(globalTranslate && globalTranslate.cal_ThisMonth) || 'Этот месяц']: [
                    moment().startOf('month'),
                    moment().endOf('day'),
                ],
                [(globalTranslate && globalTranslate.cal_LastMonth) || 'Прошлый месяц']: [
                    moment().subtract(1, 'month').startOf('month'),
                    moment().subtract(1, 'month').endOf('month'),
                ],
            },
            alwaysShowCalendars: true,
            autoUpdateInput: true,
            linkedCalendars: true,
            // CRITICAL: endOf('day') must not exceed maxDate or picker leaves input empty
            maxDate: todayEnd.clone(),
            startDate: safeStart,
            endDate: safeEnd,
            parentEl: 'body',
            opens: 'left',
            locale: {
                format: 'DD/MM/YYYY',
                separator: ' - ',
                applyLabel: (globalTranslate && globalTranslate.cal_ApplyBtn) || 'OK',
                cancelLabel: (globalTranslate && globalTranslate.cal_CancelBtn) || 'Отмена',
                fromLabel: (globalTranslate && globalTranslate.cal_from) || 'С',
                toLabel: (globalTranslate && globalTranslate.cal_to) || 'По',
                customRangeLabel: (globalTranslate && globalTranslate.cal_CustomPeriod) || 'Период',
                daysOfWeek: locDays,
                monthNames: locMonths,
                firstDay: 1,
            },
        };

        // Re-init safely if already bound
        try {
            const existing = callDetailRecords.$dateRangeSelector.data('daterangepicker');
            if (existing && typeof existing.remove === 'function') {
                existing.remove();
            }
        } catch (e) {
            // ignore
        }

        callDetailRecords.$dateRangeSelector.daterangepicker(
            options,
            callDetailRecords.cbDateRangeSelectorOnSelect,
        );

        // Force visible value immediately
        callDetailRecords.$dateRangeSelector.val(
            `${safeStart.format('DD/MM/YYYY')} - ${safeEnd.format('DD/MM/YYYY')}`,
        );
    },


    /**
     * Handles the date range selector select event.
     * @param {moment.Moment} start - The start date.
     * @param {moment.Moment} end - The end date.
     * @param {string} label - The label.
     */
    cbDateRangeSelectorOnSelect(start, end, label) {
        // Only pass search keyword, dates are read directly from date range selector
        callDetailRecords.applyFilter(callDetailRecords.$globalSearch.val());
        // State will be saved automatically in draw event after filter is applied
    },

    /**
     * Applies the filter to the data table.
     * @param {string} text - The filter text.
     */
    applyFilter(text) {
        if (!callDetailRecords.dataTable || typeof callDetailRecords.dataTable.search !== 'function') {
            return;
        }
        callDetailRecords.dataTable.search(text || '').draw();
        if (callDetailRecords.$globalSearch && callDetailRecords.$globalSearch.length) {
            callDetailRecords.$globalSearch.closest('div').addClass('loading');
        }
    },
};

/**
 *  Initialize CDR table on document ready
 */
$(document).ready(() => {
    callDetailRecords.initialize();
});
