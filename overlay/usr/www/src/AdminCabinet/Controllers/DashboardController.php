<?php
/*
 * SkyScale — ATC Dashboard
 */

namespace MikoPBX\AdminCabinet\Controllers;

/**
 * Dashboard Controller — KPI, charts, recent calls, queues, quick actions.
 * Data loaded client-side via REST /pbxcore/api/v3/cdr
 */
class DashboardController extends BaseController
{
    public function indexAction(): void
    {
        // View only
    }
}
