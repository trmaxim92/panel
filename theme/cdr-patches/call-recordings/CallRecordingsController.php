<?php
/*
 * SkyScale — Call Recordings page (Mango-style library)
 * Thin controller: view only; data via REST /pbxcore/api/v3/cdr
 */

namespace MikoPBX\AdminCabinet\Controllers;

/**
 * Call Recordings Controller
 *
 * Separate UI for conversation recordings (flat list with inline play).
 * Reuses CDR REST API; filters to legs that have recordingfile.
 */
class CallRecordingsController extends BaseController
{
    /**
     * Recordings index — static shell; JS loads data from REST API.
     */
    public function indexAction(): void
    {
        // View only
    }
}
