<?php
/*
 * SkyScale — Call Recordings page (library + storage cleanup)
 */

namespace MikoPBX\AdminCabinet\Controllers;

use MikoPBX\Core\System\Directories;

/**
 * Call Recordings Controller
 *
 * UI for conversation recordings; data via REST /pbxcore/api/v3/cdr.
 * purgeAction removes local recording files older than N days.
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

    /**
     * AJAX: delete recording files older than given retention days.
     * POST days=30|90|180|360|1080
     */
    public function purgeAction(): void
    {
        $this->view->success = false;
        $this->view->message = '';
        $this->view->data = [
            'deletedFiles' => 0,
            'freedBytes' => 0,
            'days' => 0,
        ];

        if (!$this->request->isPost()) {
            $this->view->message = 'Метод не поддерживается';
            return;
        }

        $days = (int)$this->request->getPost('days');
        $allowed = [7, 14, 30, 90, 180, 360, 1080];
        if (!in_array($days, $allowed, true)) {
            $this->view->message = 'Выберите срок очистки';
            return;
        }

        $monitorDir = realpath(Directories::getDir(Directories::AST_MONITOR_DIR));
        if ($monitorDir === false || !is_dir($monitorDir)) {
            $this->view->message = 'Каталог записей не найден';
            return;
        }

        $cutoff = time() - ($days * 86400);
        $allowedBase = rtrim($monitorDir, DIRECTORY_SEPARATOR) . DIRECTORY_SEPARATOR;
        $deletedFiles = 0;
        $freedBytes = 0;
        $extensions = ['webm', 'wav', 'wav16', 'wav48', 'mp3', 'ogg', 'mp4'];

        try {
            $iterator = new \RecursiveIteratorIterator(
                new \RecursiveDirectoryIterator(
                    $monitorDir,
                    \FilesystemIterator::SKIP_DOTS
                ),
                \RecursiveIteratorIterator::CHILD_FIRST
            );

            foreach ($iterator as $fileInfo) {
                /** @var \SplFileInfo $fileInfo */
                if ($fileInfo->isFile()) {
                    $ext = strtolower($fileInfo->getExtension());
                    if (!in_array($ext, $extensions, true)) {
                        continue;
                    }
                    $mtime = $fileInfo->getMTime();
                    if ($mtime === false || $mtime >= $cutoff) {
                        continue;
                    }
                    $real = $fileInfo->getRealPath();
                    if ($real === false || !str_starts_with($real, $allowedBase)) {
                        continue;
                    }
                    $size = $fileInfo->getSize();
                    if (@unlink($real)) {
                        $deletedFiles++;
                        $freedBytes += max(0, (int)$size);
                    }
                    continue;
                }

                if ($fileInfo->isDir()) {
                    $real = $fileInfo->getRealPath();
                    if ($real === false || $real === $monitorDir || !str_starts_with($real, $allowedBase)) {
                        continue;
                    }
                    @rmdir($real);
                }
            }
        } catch (\Throwable $e) {
            $this->view->message = 'Ошибка очистки: ' . $e->getMessage();
            return;
        }

        $this->view->success = true;
        $this->view->message = $deletedFiles > 0
            ? "Удалено файлов: {$deletedFiles}"
            : 'Нет записей старше выбранного срока';
        $this->view->data = [
            'deletedFiles' => $deletedFiles,
            'freedBytes' => $freedBytes,
            'days' => $days,
        ];
    }
}
