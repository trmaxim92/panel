<?php
/*
 * MikoPBX - free phone system for small business
 * Copyright © 2017-2023 Alexey Portnov and Nikolay Beketov
 *
 * SkyScale overlay: limit log rotation and cut DTMF/verbose flood
 * so /storage/.../log/asterisk does not grow to tens of GB.
 */

namespace MikoPBX\Core\Asterisk\Configs;


use MikoPBX\Core\System\Directories;
use MikoPBX\Core\System\Util;

/**
 * Class LoggerConf
 *
 * Represents the configuration for logger.conf.
 *
 * @package MikoPBX\Core\Asterisk\Configs
 */
class LoggerConf extends AsteriskConfigClass
{
    /**
     * The module hook applying priority.
     *
     * @var int
     */
    public int $priority = 1000;

    /**
     * The description of the configuration.
     *
     * @var string
     */
    protected string $description = 'logger.conf';


    /**
     * Generates the configuration for the logger.conf file.
     *
     * @return void
     */
    protected function generateConfigProtected(): void
    {
        $logDir = Directories::getDir(Directories::CORE_LOGS_DIR). '/asterisk/';

        // Create the log directory if it doesn't exist
        Util::mwMkdir($logDir);

        // Generate the configuration content
        // rotatesize/rotatecount: keep disk use bounded (SkyScale)
        $conf = "[general]\n";
        $conf .= "rotatesize = 50M\n";
        $conf .= "rotatecount = 2\n";
        $conf .= "queue_log = no\n";
        $conf .= "dateformat = %F %T\n";
        $conf .= "\n";
        $conf .= "[logfiles]\n";
        $conf .= "console => error,verbose(4)\n\n";
        $conf .= "{$logDir}security_log => security\n";
        $conf .= "{$logDir}messages => notice,warning\n";
        $conf .= "{$logDir}error => error\n";
        // No DTMF spam in verbose file — it was filling ~20GB of rotations.
        $conf .= "{$logDir}verbose => verbose(1),warning,error\n";
        $conf .= "\n";

        // Write the configuration content to the file
        $this->saveConfig($conf, $this->description);
    }
}
