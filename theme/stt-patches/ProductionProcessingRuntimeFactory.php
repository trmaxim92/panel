<?php

declare(strict_types=1);

namespace Modules\ModuleCloudSpeechToText\Lib\Processing;

use MikoPBX\Core\System\{Directories, Util};
use MikoPBX\Modules\Models\ModulesModelsBase;
use Modules\ModuleCloudSpeechToText\Lib\Audio\AsyncAudioPreparer;
use Modules\ModuleCloudSpeechToText\Lib\Audio\AudioPreparationException;
use Modules\ModuleCloudSpeechToText\Lib\Clock\SystemClock;
use Modules\ModuleCloudSpeechToText\Lib\Database\ModuleDatabaseConnection;
use Modules\ModuleCloudSpeechToText\Lib\Discovery\{ReadinessPolicy, RecordingPathGuard};
use Modules\ModuleCloudSpeechToText\Lib\Queue\Anchor\AnchorStatePaths;
use Modules\ModuleCloudSpeechToText\Lib\Queue\{
    DailyReservationService, JobRepository, PersistentAnchorRuntimeFactory,
    PollExecutionRepository, PollExecutionService, QueueRuntimeFactory, RemoteAttemptService
};
use Modules\ModuleCloudSpeechToText\Lib\SkyscaleProviderConfig;
use Modules\ModuleCloudSpeechToText\Lib\SpeechMikoLabV1\Http\{CurlTransport, ProductionCurlHandleFactory};
use Modules\ModuleCloudSpeechToText\Lib\SpeechMikoLabV1\LocalWhisperAdapter;
use Modules\ModuleCloudSpeechToText\Lib\SpeechMikoLabV1\SpeechMikoLabV1Client;
use Modules\ModuleCloudSpeechToText\Lib\SpeechMikoLabV1\Contract\SpeechMikoLabV1Adapter;
use Modules\ModuleCloudSpeechToText\Lib\Services\CloudSpeechToTextLogger;
use Phalcon\Di\DiInterface;

/** Single production composition root for the processing worker. */
final readonly class ProductionProcessingRuntimeFactory
{
    public function __construct(private DiInterface $di)
    {
    }

    public function create(string $workload = 'all', ?callable $shouldStop = null): ProcessingIterationService
    {
        $clock = new SystemClock();
        $db = ModuleDatabaseConnection::fromPhalcon(
            $this->di->getShared(ModulesModelsBase::getConnectionServiceName('ModuleCloudSpeechToText')),
        );
        $modulesDirectory = Directories::getDir(Directories::CORE_MODULES_DIR);
        $anchor = (new PersistentAnchorRuntimeFactory(
            AnchorStatePaths::fromModulesDirectory($modulesDirectory),
        ))->openFailClosed();
        $queue = new QueueRuntimeFactory($db, $anchor, $clock);

        $provider = $this->createProvider($db, $clock, $workload, $shouldStop);

        $settings = $db->fetchOne("SELECT max_file_size_bytes FROM m_CloudSTTSetting WHERE singleton_key='default'");
        if ($settings === null) {
            throw new \RuntimeException('Processing settings unavailable');
        }
        $maximumFileBytes = max(1, min(ReadinessPolicy::HARD_MAX_FILE_SIZE_BYTES, (int)$settings['max_file_size_bytes']));
        $audio = new AsyncAudioPreparer(Util::which('ffprobe') ?: null, Util::which('ffmpeg') ?: null, niceBinary: Util::which('nice') ?: null);
        $audioPreparationReady = false;
        if ($workload !== 'results') {
            try {
                $audio->cleanupStartupArtifacts();
                $audioPreparationReady = true;
            } catch (AudioPreparationException) {
                CloudSpeechToTextLogger::event('processing', 'audio_staging_cleanup_deferred', 'Audio staging cleanup deferred', LOG_WARNING, ['workload' => $workload]);
            }
        }
        $jobs = new JobRepository($db, clock: $clock);
        $pollExecutions = new PollExecutionService($db, new PollExecutionRepository($db), $clock);
        $timezone = date_default_timezone_get();
        new \DateTimeZone($timezone);
        $providerHealth = new ProviderHealthService($db, $provider, $clock);

        return new ProcessingIterationService(
            $clock,
            new ProcessingRecoveryService($db, $queue->recoveryCoordinator(), $queue->queueRecovery(), $workload !== 'results', $workload === 'submit', $audioPreparationReady),
            $jobs,
            new PollingProcessor($db, $clock, $pollExecutions, $provider),
            new SubmissionProcessor(
                $db,
                $clock,
                Directories::getDir(Directories::AST_MONITOR_DIR),
                new RecordingPathGuard($maximumFileBytes),
                new AsyncAudioPreparationPort($audio),
                new SubmissionAdmissionService($db, $clock),
                new DailyReservationService($db, $clock),
                $queue->submitFence(),
                new RemoteAttemptService($db, clock: $clock),
                $provider,
                $timezone,
                $providerHealth,
            ),
            new SubmissionAdmissionService($db, $clock),
            new TerminalPartReconciliationService($db),
            new TranscriptPublicationService($db, $clock),
            'cloud-stt-processing-' . getmypid(),
            new MaintenanceService($db),
            $providerHealth,
            $workload,
        );
    }

    private function createProvider(
        ModuleDatabaseConnection $db,
        SystemClock $clock,
        string $workload,
        ?callable $shouldStop,
    ): SpeechMikoLabV1Adapter {
        $cfg = SkyscaleProviderConfig::load();
        if ($cfg->isLocal()) {
            return new LocalWhisperAdapter(
                $cfg->sidecarUrl,
                $cfg->whisperModel,
                $cfg->whisperLanguage,
            );
        }

        // LazyApiTokenIssuer breaks the circular wiring between the client
        // (needs a credential provider for balance/submit/poll) and the
        // credential provider (needs something that can issue/revoke,
        // a capability the same client also has): it is bound to the one
        // real client below, right after that client is constructed.
        $issuer = new LazyApiTokenIssuer();
        $credentials = new ApiTokenCredentialProvider(
            $db,
            $issuer,
            new ApiTokenStore(dirname(__DIR__, 2) . '/db/private'),
            new CoreLicenseKeyProvider(),
            $clock,
        );
        $provider = new SpeechMikoLabV1Client(
            new CoreLicenseKeyProvider(),
            new CurlTransport(new ProductionCurlHandleFactory(), new ProcessingTransferControl($db, $clock, $workload === 'submit', $shouldStop)),
            $credentials,
        );
        $issuer->bind($provider);
        return $provider;
    }
}
