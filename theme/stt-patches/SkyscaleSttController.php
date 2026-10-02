<?php
/*
 * SkyScale — Local Whisper settings (self-contained, no module class autoload)
 */

namespace MikoPBX\AdminCabinet\Controllers;

class SkyscaleSttController extends BaseController
{
    private const CONFIG_PATH = '/storage/usbdisk1/mikopbx/custom_modules/ModuleCloudSpeechToText/db/private/skyscale-provider.json';

    public function initialize(): void
    {
        parent::initialize();
        $this->view->submitMode = null;
    }

    public function indexAction(): void
    {
        $cfg = $this->loadConfig();
        $this->view->providerMode = $cfg['provider_mode'];
        $this->view->sidecarUrl = $cfg['sidecar_url'];
        $this->view->whisperModel = $cfg['whisper_model'];
        $this->view->whisperLanguage = $cfg['whisper_language'];
        $this->view->sidecarHealthy = $this->probeSidecar($cfg['sidecar_url']);
    }

    public function saveAction(): void
    {
        $this->view->success = false;
        if (!$this->request->isPost()) {
            $this->view->message = 'Метод не поддерживается';
            return;
        }
        $posted = [
            'provider_mode' => $this->postString('provider_mode'),
            'sidecar_url' => $this->postString('sidecar_url'),
            'whisper_model' => $this->postString('whisper_model'),
            'whisper_language' => $this->postString('whisper_language'),
        ];
        try {
            $cfg = $this->saveConfig($posted);
        } catch (\Throwable $e) {
            $this->view->message = 'Не удалось записать настройки: ' . $e->getMessage();
            return;
        }
        $this->view->success = true;
        $this->view->message = 'Настройки сохранены';
        $this->view->data = [
            'provider_mode' => $cfg['provider_mode'],
            'sidecar_url' => $cfg['sidecar_url'],
            'whisper_model' => $cfg['whisper_model'],
            'whisper_language' => $cfg['whisper_language'],
            'sidecar_healthy' => $this->probeSidecar($cfg['sidecar_url']),
        ];
    }

    private function postString(string $key): string
    {
        $value = $this->request->getPost($key);
        if (is_array($value)) {
            $value = reset($value);
        }
        return trim((string)$value);
    }

    public function healthAction(): void
    {
        $cfg = $this->loadConfig();
        $ok = $this->probeSidecar($cfg['sidecar_url']);
        $this->view->success = $ok;
        $this->view->data = ['sidecar_healthy' => $ok, 'sidecar_url' => $cfg['sidecar_url']];
        $this->view->message = $ok ? 'Sidecar доступен' : 'Sidecar недоступен';
    }

    /** @return array{provider_mode:string,sidecar_url:string,whisper_model:string,whisper_language:string} */
    private function loadConfig(): array
    {
        $defaults = [
            'provider_mode' => 'local_whisper',
            'sidecar_url' => 'http://127.0.0.1:8791',
            'whisper_model' => 'base',
            'whisper_language' => 'ru',
        ];
        if (!is_readable(self::CONFIG_PATH)) {
            return $defaults;
        }
        $raw = file_get_contents(self::CONFIG_PATH);
        $data = is_string($raw) ? json_decode($raw, true) : null;
        if (!is_array($data)) {
            return $defaults;
        }
        $mode = (string)($data['provider_mode'] ?? $defaults['provider_mode']);
        if ($mode !== 'local_whisper' && $mode !== 'mikolab') {
            $mode = 'local_whisper';
        }
        $model = (string)($data['whisper_model'] ?? 'base');
        if (!in_array($model, ['tiny', 'base', 'small'], true)) {
            $model = 'base';
        }
        $lang = (string)($data['whisper_language'] ?? 'ru') ?: 'ru';
        $url = (string)($data['sidecar_url'] ?? $defaults['sidecar_url']) ?: $defaults['sidecar_url'];
        return [
            'provider_mode' => $mode,
            'sidecar_url' => $url,
            'whisper_model' => $model,
            'whisper_language' => $lang,
        ];
    }

    /** @param array<string,string> $input */
    private function saveConfig(array $input): array
    {
        $current = $this->loadConfig();
        $next = $this->loadConfig(); // normalize via load
        $merged = [
            'provider_mode' => $input['provider_mode'] !== '' ? $input['provider_mode'] : $current['provider_mode'],
            'sidecar_url' => $input['sidecar_url'] !== '' ? $input['sidecar_url'] : $current['sidecar_url'],
            'whisper_model' => $input['whisper_model'] !== '' ? $input['whisper_model'] : $current['whisper_model'],
            'whisper_language' => $input['whisper_language'] !== '' ? $input['whisper_language'] : $current['whisper_language'],
        ];
        // Re-validate through write+load
        $dir = dirname(self::CONFIG_PATH);
        if (!is_dir($dir)) {
            mkdir($dir, 0770, true);
        }
        $mode = $merged['provider_mode'];
        if ($mode !== 'local_whisper' && $mode !== 'mikolab') {
            $mode = 'local_whisper';
        }
        $model = $merged['whisper_model'];
        if (!in_array($model, ['tiny', 'base', 'small'], true)) {
            $model = 'base';
        }
        $payload = [
            'provider_mode' => $mode,
            'sidecar_url' => $merged['sidecar_url'] ?: 'http://127.0.0.1:8791',
            'whisper_model' => $model,
            'whisper_language' => $merged['whisper_language'] ?: 'ru',
        ];
        $json = json_encode($payload, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . "\n";
        $tmp = self::CONFIG_PATH . '.tmp';
        if (file_put_contents($tmp, $json) === false) {
            throw new \RuntimeException('нет права записи в каталог настроек');
        }
        if (!@rename($tmp, self::CONFIG_PATH) && file_put_contents(self::CONFIG_PATH, $json) === false) {
            @unlink($tmp);
            throw new \RuntimeException('файл настроек недоступен для записи');
        }
        @chmod(self::CONFIG_PATH, 0664);
        return $payload;
    }

    private function probeSidecar(string $url): bool
    {
        $ch = curl_init(rtrim($url, '/') . '/health');
        if ($ch === false) {
            return false;
        }
        curl_setopt_array($ch, [
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 2,
            CURLOPT_TIMEOUT => 3,
        ]);
        $raw = curl_exec($ch);
        $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        if ($raw === false || $code !== 200) {
            return false;
        }
        $json = json_decode($raw, true);
        return is_array($json) && !empty($json['ok']);
    }
}
