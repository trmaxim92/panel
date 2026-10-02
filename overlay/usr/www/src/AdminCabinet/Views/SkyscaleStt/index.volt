<div class="ss-stt-page">
<script>$('body').addClass('ss-stt-route');</script>
    <div class="ss-stt-head">
        <div class="ss-stt-ico"><i class="microphone icon"></i></div>
        <div>
            <h1>Транскрибация Whisper</h1>
            <p>Локальный провайдер для модуля Cloud Speech-to-Text</p>
        </div>
    </div>

    <div class="ss-stt-card">
        <div class="ss-stt-status" id="ss-stt-status">
            {% if sidecarHealthy %}
                <span class="ss-stt-pill is-ok">Sidecar онлайн</span>
            {% else %}
                <span class="ss-stt-pill is-bad">Sidecar офлайн</span>
            {% endif %}
        </div>

        <form id="ss-stt-form" class="ui form">
            <div class="field">
                <label for="ss-stt-mode">Провайдер</label>
                <select name="provider_mode" id="ss-stt-mode" class="ui dropdown">
                    <option value="local_whisper"{% if providerMode == 'local_whisper' %} selected{% endif %}>Local Whisper (CPU)</option>
                    <option value="mikolab"{% if providerMode == 'mikolab' %} selected{% endif %}>Cloud Miko Lab</option>
                </select>
            </div>
            <div class="two fields">
                <div class="field">
                    <label for="ss-stt-model">Модель Whisper</label>
                    <select name="whisper_model" id="ss-stt-model" class="ui dropdown">
                        <option value="tiny"{% if whisperModel == 'tiny' %} selected{% endif %}>tiny (быстрее)</option>
                        <option value="base"{% if whisperModel == 'base' %} selected{% endif %}>base (рекомендуется)</option>
                        <option value="small"{% if whisperModel == 'small' %} selected{% endif %}>small (точнее, больше RAM)</option>
                    </select>
                </div>
                <div class="field">
                    <label for="ss-stt-lang">Язык</label>
                    <select name="whisper_language" id="ss-stt-lang" class="ui dropdown">
                        <option value="ru"{% if whisperLanguage == 'ru' %} selected{% endif %}>Русский</option>
                        <option value="en"{% if whisperLanguage == 'en' %} selected{% endif %}>English</option>
                        <option value="auto"{% if whisperLanguage == 'auto' %} selected{% endif %}>Авто</option>
                    </select>
                </div>
            </div>
            <div class="field">
                <label for="ss-stt-url">URL sidecar</label>
                <input type="text" name="sidecar_url" id="ss-stt-url" value="{{ sidecarUrl }}" placeholder="http://127.0.0.1:8791">
            </div>
            <div class="ss-stt-actions">
                <button type="submit" class="ui primary button" id="ss-stt-save">
                    <i class="save icon"></i> Сохранить
                </button>
                <button type="button" class="ui button" id="ss-stt-health">
                    <i class="heartbeat icon"></i> Проверить sidecar
                </button>
                <a class="ui button" href="{{ url.get('module-cloud-speech-to-text') }}/index">
                    Открыть модуль STT
                </a>
            </div>
            <div class="ss-stt-hint">
                В режиме Local Whisper аудио не уходит в облако. Нужен запущенный sidecar (faster-whisper).
                Модуль Cloud Speech-to-Text должен быть активирован и с подтверждением privacy (как раньше).
            </div>
        </form>
    </div>
</div>

<script>
(function () {
  function boot() {
    $('body').addClass('ss-stt-route');
    $('#page-header').hide();
    var $mode = $('#ss-stt-mode');
    var $model = $('#ss-stt-model');
    var $lang = $('#ss-stt-lang');

    // Native <select> + Semantic dropdown wrapper
    $mode.add($model).add($lang).dropdown();

    // Force visible selection from current <option selected>
    [$mode, $model, $lang].forEach(function ($el) {
      var v = $el.val();
      if (v) {
        $el.dropdown('set selected', v);
      }
    });

    $('#ss-stt-form').on('submit', function (e) {
      e.preventDefault();
      var $btn = $('#ss-stt-save').addClass('loading disabled');
      function fieldVal($el) {
        var v = $el.dropdown('get value');
        if (Array.isArray(v)) v = v[0];
        if (!v) v = $el.val();
        if (Array.isArray(v)) v = v[0];
        return String(v || '').trim();
      }
      $.post(globalRootUrl + 'skyscale-stt/save', {
        provider_mode: fieldVal($mode),
        whisper_model: fieldVal($model),
        whisper_language: fieldVal($lang),
        sidecar_url: $('#ss-stt-url').val()
      }, function (res) {
        $btn.removeClass('loading disabled');
        var msg = (res && res.message) || 'Сохранено';
        if (res && res.success) {
          if (typeof UserMessage !== 'undefined' && UserMessage.showInformation) {
            UserMessage.showInformation(msg);
          } else {
            alert(msg);
          }
          var ok = res.data && res.data.sidecar_healthy;
          $('#ss-stt-status').html(ok
            ? '<span class="ss-stt-pill is-ok">Sidecar онлайн</span>'
            : '<span class="ss-stt-pill is-bad">Sidecar офлайн</span>');
        } else {
          if (typeof UserMessage !== 'undefined' && UserMessage.showError) {
            UserMessage.showError(msg || 'Ошибка сохранения');
          } else {
            alert(msg || 'Ошибка сохранения');
          }
        }
      }, 'json').fail(function () {
        $btn.removeClass('loading disabled');
        if (typeof UserMessage !== 'undefined' && UserMessage.showError) {
          UserMessage.showError('Ошибка запроса');
        } else {
          alert('Ошибка запроса');
        }
      });
    });

    $('#ss-stt-health').on('click', function () {
      var $btn = $(this).addClass('loading disabled');
      $.getJSON(globalRootUrl + 'skyscale-stt/health', function (res) {
        $btn.removeClass('loading disabled');
        var ok = res && res.success;
        var msg = (res && res.message) || (ok ? 'Sidecar доступен' : 'Sidecar недоступен');
        $('#ss-stt-status').html(ok
          ? '<span class="ss-stt-pill is-ok">Sidecar онлайн</span>'
          : '<span class="ss-stt-pill is-bad">Sidecar офлайн</span>');
        if (typeof UserMessage !== 'undefined') {
          if (ok && UserMessage.showInformation) UserMessage.showInformation(msg);
          else if (!ok && UserMessage.showError) UserMessage.showError(msg);
          else alert(msg);
        } else {
          alert(msg);
        }
      }).fail(function () {
        $btn.removeClass('loading disabled');
        if (typeof UserMessage !== 'undefined' && UserMessage.showError) {
          UserMessage.showError('Ошибка запроса');
        } else {
          alert('Ошибка запроса');
        }
      });
    });
  }

  if (window.jQuery) {
    $(boot);
  } else {
    document.addEventListener('DOMContentLoaded', boot);
  }
})();
</script>
