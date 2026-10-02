<?php

declare(strict_types=1);

namespace Modules\ModuleCloudSpeechToText\Lib\SpeechMikoLabV1;

use Modules\ModuleCloudSpeechToText\Lib\SpeechMikoLabV1\DTO\{
    BalanceCheckResult,
    DeliveryClassification,
    FailureCategory,
    PollOutcome,
    PollResultCommand,
    PollResultResult,
    ProviderChunk,
    ProviderFailure,
    RetryClass,
    SubmitRecordingResult,
    TokenIssueFailure,
    TokenIssueResult,
    TokenRevokeOutcome,
    TokenRevokeResult,
    TransportEvidence
};
use Modules\ModuleCloudSpeechToText\Lib\SpeechMikoLabV1\Contract\SpeechMikoLabV1Adapter;
use Modules\ModuleCloudSpeechToText\Lib\SpeechMikoLabV1\DTO\AuthorizedSubmitCommand;
use Modules\ModuleCloudSpeechToText\Lib\SpeechMikoLabV1\Exception\InvalidCommandException;
use Modules\ModuleCloudSpeechToText\Lib\SpeechMikoLabV1\Security\ApiToken;
use DateTimeImmutable;

/**
 * SkyScale — local faster-whisper provider behind SpeechMikoLabV1Adapter.
 */
final class LocalWhisperAdapter implements SpeechMikoLabV1Adapter
{
    public function __construct(
        private readonly string $sidecarBaseUrl,
        private readonly string $defaultModel = 'base',
        private readonly string $defaultLanguage = 'ru',
        private readonly int $timeoutSeconds = 15,
    ) {
    }

    public function checkBalance(): BalanceCheckResult
    {
        $reachable = $this->healthOk();
        return new BalanceCheckResult(
            reachable: $reachable,
            authorized: true,
            balanceState: $reachable ? 'recognized' : 'unparsed',
            amount: $reachable ? '999999' : null,
            currency: $reachable ? 'LOCAL' : null,
            checkedAt: new DateTimeImmutable(),
            providerRequestRef: 'local-whisper',
            failure: $reachable ? null : new ProviderFailure(
                FailureCategory::RemoteUnavailable,
                RetryClass::Safe,
                'Local Whisper sidecar is unreachable',
            ),
        );
    }

    public function submitRecording(AuthorizedSubmitCommand $command): SubmitRecordingResult
    {
        $command->assertSubmitCapabilityAvailable();
        try {
            $curlFile = $command->recording->toCurlFile($command->recordingId . '.ogg');
            $path = $curlFile->getFilename();
        } catch (InvalidCommandException) {
            $command->recording->release();
            return new SubmitRecordingResult(
                false,
                failure: new ProviderFailure(FailureCategory::InvalidResponse, RetryClass::Safe, 'Prepared recording is unavailable'),
                deliveryClassification: DeliveryClassification::DefinitelyNotSent,
                transportEvidence: new TransportEvidence(affirmativePreBodyFailure: true),
            );
        }

        $command->networkAuthorization->consumeForSubmit();
        $command->markSubmitCapabilityConsumed();

        $language = $this->mapLanguage($command->languageCode);
        $model = $this->defaultModel;
        $stagedPath = null;

        try {
            $stagedPath = $this->stageAudioCopy($path, $command->attemptId);
            $response = $this->httpJson('POST', '/jobs', [
                'path' => $stagedPath,
                'language' => $language,
                'model' => $model,
            ]);
        } catch (\Throwable $e) {
            if (is_string($stagedPath) && is_file($stagedPath)) {
                @unlink($stagedPath);
            }
            $command->recording->release();
            return new SubmitRecordingResult(
                false,
                failure: new ProviderFailure(FailureCategory::NetworkUnavailable, RetryClass::Safe, 'Whisper sidecar submit failed: ' . $e->getMessage()),
                deliveryClassification: DeliveryClassification::DefinitelyNotSent,
                transportEvidence: new TransportEvidence(
                    affirmativePreBodyFailure: true,
                    transportError: $e->getMessage(),
                ),
            );
        }
        $command->recording->release();

        $jobId = is_array($response) ? (string)($response['id'] ?? '') : '';
        if ($jobId === '' || empty($response['ok'])) {
            if (is_string($stagedPath) && is_file($stagedPath)) {
                @unlink($stagedPath);
            }
            return new SubmitRecordingResult(
                false,
                failure: new ProviderFailure(
                    FailureCategory::InvalidResponse,
                    RetryClass::Safe,
                    (string)($response['error'] ?? 'Whisper sidecar rejected job'),
                ),
                deliveryClassification: DeliveryClassification::DefinitelyNotSent,
                transportEvidence: new TransportEvidence(responseStarted: true, httpStatus: 400),
            );
        }

        return new SubmitRecordingResult(
            true,
            $jobId,
            (new DateTimeImmutable())->modify('+5 seconds'),
            'local-whisper:' . $jobId,
            null,
            DeliveryClassification::ConfirmedAccepted,
            new TransportEvidence(connected: true, responseStarted: true, httpStatus: 202, acceptedOperationId: true),
        );
    }

    private function stageAudioCopy(string $sourcePath, string $attemptId): string
    {
        $safe = preg_replace('/[^A-Za-z0-9._-]+/', '_', $attemptId) ?: bin2hex(random_bytes(8));
        $dir = dirname(__DIR__, 2) . '/db/private/whisper-staging';
        if (!is_dir($dir) && !mkdir($dir, 0770, true) && !is_dir($dir)) {
            throw new \RuntimeException('Cannot create whisper staging directory');
        }
        $dest = $dir . '/' . $safe . '.ogg';
        if (!@link($sourcePath, $dest) && !@copy($sourcePath, $dest)) {
            throw new \RuntimeException('Cannot stage audio for Whisper');
        }
        return $dest;
    }

    public function pollResult(PollResultCommand $command): PollResultResult
    {
        $id = rawurlencode($command->operationId);
        try {
            $response = $this->httpJson('GET', '/jobs/' . $id);
        } catch (\Throwable $e) {
            return new PollResultResult(
                PollOutcome::TransientFailure,
                failure: new ProviderFailure(FailureCategory::NetworkUnavailable, RetryClass::Poll, $e->getMessage()),
            );
        }

        if (empty($response['ok'])) {
            $err = (string)($response['error'] ?? '');
            if ($err === 'not_found') {
                return new PollResultResult(PollOutcome::NotFoundUnconfirmed);
            }
            return new PollResultResult(
                PollOutcome::TransientFailure,
                failure: new ProviderFailure(FailureCategory::RemoteUnavailable, RetryClass::Poll, $err ?: 'poll failed'),
            );
        }

        $status = (string)($response['status'] ?? '');
        if ($status === 'queued' || $status === 'running') {
            return new PollResultResult(PollOutcome::Pending, providerRequestRef: 'local-whisper:' . $command->operationId);
        }
        if ($status === 'failed') {
            return new PollResultResult(
                PollOutcome::Rejected,
                failure: new ProviderFailure(
                    FailureCategory::ProviderUnknown,
                    RetryClass::Manual,
                    (string)($response['error'] ?? 'transcription failed'),
                ),
                providerRequestRef: 'local-whisper:' . $command->operationId,
            );
        }
        if ($status !== 'completed' || !is_array($response['result'] ?? null)) {
            return new PollResultResult(PollOutcome::InvalidResponseUnconfirmed);
        }

        $chunks = [];
        foreach (($response['result']['chunks'] ?? []) as $row) {
            if (!is_array($row)) {
                continue;
            }
            $start = (int)($row['start_ms'] ?? 0);
            $end = (int)($row['end_ms'] ?? $start);
            $text = trim((string)($row['text'] ?? ''));
            if ($text === '' || $end < $start) {
                continue;
            }
            $channel = array_key_exists('channel', $row) && $row['channel'] !== null ? (int)$row['channel'] : null;
            $chunks[] = new ProviderChunk($start, $end, $text, $channel);
        }

        if ($chunks === [] && trim((string)($response['result']['plain_text'] ?? '')) !== '') {
            $plain = trim((string)$response['result']['plain_text']);
            $chunks[] = new ProviderChunk(0, (int)($response['result']['duration_ms'] ?? 0), $plain, null);
        }

        return new PollResultResult(PollOutcome::Completed, $chunks, 'local-whisper:' . $command->operationId);
    }

    public function classifyTransportOutcome(TransportEvidence $evidence): DeliveryClassification
    {
        if ($evidence->acceptedOperationId) {
            return DeliveryClassification::ConfirmedAccepted;
        }
        if ($evidence->affirmativePreBodyFailure || $evidence->contractProvenNonBillableRejection) {
            return DeliveryClassification::DefinitelyNotSent;
        }
        if ($evidence->uploadStarted || $evidence->responseStarted || $evidence->unknownException) {
            return DeliveryClassification::PossiblySent;
        }
        return DeliveryClassification::DefinitelyNotSent;
    }

    public function issueApiToken(string $installationName): TokenIssueResult
    {
        // Local mode does not use Miko Lab tokens; return a syntactically valid dummy.
        $token = new ApiToken('mlk_' . str_pad(bin2hex(random_bytes(20)), 40, '0'));
        return new TokenIssueResult($token, trim($installationName) !== '' ? trim($installationName) : 'local-whisper');
    }

    public function revokeApiToken(string $tokenPrefix): TokenRevokeResult
    {
        return new TokenRevokeResult(TokenRevokeOutcome::Revoked);
    }

    private function mapLanguage(string $languageCode): string
    {
        if ($languageCode === '' || $languageCode === 'auto') {
            return 'auto';
        }
        // Module uses BCP47 like ru-RU → whisper wants "ru"
        $primary = strtolower(explode('-', $languageCode)[0] ?? 'ru');
        return $primary !== '' ? $primary : $this->defaultLanguage;
    }

    private function healthOk(): bool
    {
        try {
            $r = $this->httpJson('GET', '/health');
            return !empty($r['ok']);
        } catch (\Throwable) {
            return false;
        }
    }

    /** @return array<string,mixed> */
    private function httpJson(string $method, string $path, ?array $body = null): array
    {
        $url = rtrim($this->sidecarBaseUrl, '/') . $path;
        $ch = curl_init($url);
        if ($ch === false) {
            throw new \RuntimeException('curl_init failed');
        }
        $headers = ['Accept: application/json'];
        curl_setopt_array($ch, [
            CURLOPT_CUSTOMREQUEST => $method,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => min(5, $this->timeoutSeconds),
            CURLOPT_TIMEOUT => $this->timeoutSeconds,
            CURLOPT_HTTPHEADER => $headers,
        ]);
        if ($body !== null) {
            $payload = json_encode($body, JSON_UNESCAPED_UNICODE);
            curl_setopt($ch, CURLOPT_POSTFIELDS, $payload);
            $headers[] = 'Content-Type: application/json';
            curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);
        }
        $raw = curl_exec($ch);
        $errno = curl_errno($ch);
        $status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        if ($errno !== 0 || $raw === false) {
            throw new \RuntimeException('sidecar transport error #' . $errno);
        }
        $decoded = json_decode($raw, true);
        if (!is_array($decoded)) {
            throw new \RuntimeException('sidecar returned non-json HTTP ' . $status);
        }
        $decoded['_http_status'] = $status;
        return $decoded;
    }
}
