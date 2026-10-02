<?php

declare(strict_types=1);

namespace Modules\ModuleCloudSpeechToText\Lib;

/**
 * SkyScale provider settings for ModuleCloudSpeechToText (JSON beside module private DB).
 */
final class SkyscaleProviderConfig
{
    public const MODE_MIKOLAB = 'mikolab';
    public const MODE_LOCAL = 'local_whisper';

    public function __construct(
        public readonly string $providerMode,
        public readonly string $sidecarUrl,
        public readonly string $whisperModel,
        public readonly string $whisperLanguage,
    ) {
    }

    public static function configPath(): string
    {
        return dirname(__DIR__) . '/db/private/skyscale-provider.json';
    }

    public static function load(): self
    {
        $path = self::configPath();
        $data = [];
        if (is_readable($path)) {
            $raw = file_get_contents($path);
            $decoded = is_string($raw) ? json_decode($raw, true) : null;
            if (is_array($decoded)) {
                $data = $decoded;
            }
        }
        $mode = (string)($data['provider_mode'] ?? self::MODE_LOCAL);
        if ($mode !== self::MODE_MIKOLAB && $mode !== self::MODE_LOCAL) {
            $mode = self::MODE_LOCAL;
        }
        $model = (string)($data['whisper_model'] ?? 'base');
        if (!in_array($model, ['tiny', 'base', 'small'], true)) {
            $model = 'base';
        }
        $lang = (string)($data['whisper_language'] ?? 'ru');
        if ($lang === '') {
            $lang = 'ru';
        }
        $url = (string)($data['sidecar_url'] ?? 'http://127.0.0.1:8791');
        if ($url === '') {
            $url = 'http://127.0.0.1:8791';
        }
        return new self($mode, $url, $model, $lang);
    }

    /** @param array{provider_mode?:string,sidecar_url?:string,whisper_model?:string,whisper_language?:string} $data */
    public static function save(array $data): self
    {
        $current = self::load();
        $next = [
            'provider_mode' => $data['provider_mode'] ?? $current->providerMode,
            'sidecar_url' => $data['sidecar_url'] ?? $current->sidecarUrl,
            'whisper_model' => $data['whisper_model'] ?? $current->whisperModel,
            'whisper_language' => $data['whisper_language'] ?? $current->whisperLanguage,
        ];
        $cfg = self::fromArray($next);
        $path = self::configPath();
        $dir = dirname($path);
        if (!is_dir($dir)) {
            mkdir($dir, 0770, true);
        }
        file_put_contents(
            $path,
            json_encode([
                'provider_mode' => $cfg->providerMode,
                'sidecar_url' => $cfg->sidecarUrl,
                'whisper_model' => $cfg->whisperModel,
                'whisper_language' => $cfg->whisperLanguage,
            ], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . "\n",
        );
        return $cfg;
    }

    /** @param array<string,mixed> $data */
    public static function fromArray(array $data): self
    {
        $mode = (string)($data['provider_mode'] ?? self::MODE_LOCAL);
        if ($mode !== self::MODE_MIKOLAB && $mode !== self::MODE_LOCAL) {
            $mode = self::MODE_LOCAL;
        }
        $model = (string)($data['whisper_model'] ?? 'base');
        if (!in_array($model, ['tiny', 'base', 'small'], true)) {
            $model = 'base';
        }
        $lang = (string)($data['whisper_language'] ?? 'ru') ?: 'ru';
        $url = (string)($data['sidecar_url'] ?? 'http://127.0.0.1:8791') ?: 'http://127.0.0.1:8791';
        return new self($mode, $url, $model, $lang);
    }

    public function isLocal(): bool
    {
        return $this->providerMode === self::MODE_LOCAL;
    }
}
