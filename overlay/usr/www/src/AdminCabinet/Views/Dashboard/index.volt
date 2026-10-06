<div class="ss-dash-page">
    <div class="ss-dash-head">
        <div class="ss-dash-head-left">
            <div class="ss-dash-head-ico"><i class="cloud icon"></i></div>
            <div>
                <h1>АТС</h1>
                <p>Обзор телефонной системы и звонков за выбранный период</p>
            </div>
        </div>
        <div class="ss-dash-status" id="dash-system-status">
            <span class="ss-dash-status-dot"></span>
            <div>
                <div class="ss-dash-status-title">Система работает</div>
                <div class="ss-dash-status-sub" id="dash-updated-at">обновлено —</div>
            </div>
            <a class="ss-dash-status-gear" href="{{ url('general-settings/modify') }}" title="Настройки">
                <i class="cog icon"></i>
            </a>
        </div>
    </div>

    <div class="ss-dash-kpis" id="dash-kpis">
        <div class="ss-dash-kpi" data-kpi="total">
            <div class="ss-dash-kpi-ico is-blue"><i class="phone icon"></i></div>
            <div class="ss-dash-kpi-label">Всего звонков</div>
            <div class="ss-dash-kpi-value" data-role="value">—</div>
            <div class="ss-dash-kpi-trend" data-role="trend"></div>
            <div class="ss-dash-kpi-hint">по сравнению с прошлым днём</div>
        </div>
        <div class="ss-dash-kpi" data-kpi="in">
            <div class="ss-dash-kpi-ico is-green"><i class="sign in icon"></i></div>
            <div class="ss-dash-kpi-label">Входящие</div>
            <div class="ss-dash-kpi-value" data-role="value">—</div>
            <div class="ss-dash-kpi-trend" data-role="trend"></div>
            <div class="ss-dash-kpi-hint">по сравнению с прошлым днём</div>
        </div>
        <div class="ss-dash-kpi" data-kpi="out">
            <div class="ss-dash-kpi-ico is-purple"><i class="sign out icon"></i></div>
            <div class="ss-dash-kpi-label">Исходящие</div>
            <div class="ss-dash-kpi-value" data-role="value">—</div>
            <div class="ss-dash-kpi-trend" data-role="trend"></div>
            <div class="ss-dash-kpi-hint">по сравнению с прошлым днём</div>
        </div>
        <div class="ss-dash-kpi" data-kpi="miss">
            <div class="ss-dash-kpi-ico is-red"><i class="phone slash icon"></i></div>
            <div class="ss-dash-kpi-label">Пропущенные</div>
            <div class="ss-dash-kpi-value" data-role="value">—</div>
            <div class="ss-dash-kpi-trend" data-role="trend"></div>
            <div class="ss-dash-kpi-hint">по сравнению с прошлым днём</div>
        </div>
    </div>

    <div class="ss-dash-charts">
        <div class="ss-dash-card ss-dash-dynamics">
            <div class="ss-dash-card-head">
                <h2>Динамика звонков</h2>
                <div class="ss-dash-tabs" id="dash-range-tabs">
                    <button type="button" class="is-active" data-range="today">Сегодня</button>
                    <button type="button" data-range="7d">7 дней</button>
                    <button type="button" data-range="30d">30 дней</button>
                </div>
            </div>
            <div class="ss-dash-legend" id="dash-line-legend">
                <span><i class="ss-dot is-green"></i> Входящие</span>
                <span><i class="ss-dot is-purple"></i> Исходящие</span>
                <span><i class="ss-dot is-miss"></i> Пропущенные</span>
            </div>
            <div class="ss-dash-chart-wrap" id="dash-line-chart"></div>
        </div>
        <div class="ss-dash-card ss-dash-donut-card">
            <div class="ss-dash-card-head">
                <h2>Распределение звонков</h2>
            </div>
            <div class="ss-dash-donut-row">
                <div class="ss-dash-donut" id="dash-donut"></div>
                <div class="ss-dash-donut-legend" id="dash-donut-legend"></div>
            </div>
        </div>
    </div>

    <div class="ss-dash-bottom">
        <div class="ss-dash-card ss-dash-recent">
            <div class="ss-dash-card-head">
                <h2>Последние звонки</h2>
                <a href="{{ url('call-detail-records/index') }}">Все звонки →</a>
            </div>
            <div class="ss-dash-table-wrap">
                <table class="ss-dash-table" id="dash-recent-table">
                    <thead>
                    <tr>
                        <th class="collapsing"></th>
                        <th>Дата / время</th>
                        <th>Клиент</th>
                        <th>Номер</th>
                        <th>Тип</th>
                        <th>Статус</th>
                        <th>Длительность</th>
                    </tr>
                    </thead>
                    <tbody id="dash-recent-body">
                    <tr><td colspan="7" class="ss-dash-loading">Загрузка…</td></tr>
                    </tbody>
                </table>
            </div>
        </div>

        <div class="ss-dash-card ss-dash-queues">
            <div class="ss-dash-card-head"><h2>Статистика очередей</h2></div>
            <div id="dash-queues" class="ss-dash-queue-list"></div>
        </div>

        <div class="ss-dash-card ss-dash-actions">
            <div class="ss-dash-card-head"><h2>Быстрые действия</h2></div>
            <div class="ss-dash-action-list">
                <a class="ss-dash-action" href="{{ url('extensions/modify') }}">
                    <span class="ss-dash-action-ico"><i class="user plus icon"></i></span>
                    <span>Добавить сотрудника</span>
                    <i class="chevron right icon"></i>
                </a>
                <a class="ss-dash-action" href="{{ url('call-queues/index') }}">
                    <span class="ss-dash-action-ico"><i class="users icon"></i></span>
                    <span>Настроить очередь</span>
                    <i class="chevron right icon"></i>
                </a>
                <a class="ss-dash-action" href="{{ url('ivr-menu/index') }}">
                    <span class="ss-dash-action-ico"><i class="sitemap icon"></i></span>
                    <span>Настроить IVR</span>
                    <i class="chevron right icon"></i>
                </a>
                <a class="ss-dash-action" href="{{ url('sound-files/index') }}">
                    <span class="ss-dash-action-ico"><i class="sound icon"></i></span>
                    <span>Записать приветствие</span>
                    <i class="chevron right icon"></i>
                </a>
                <a class="ss-dash-action" href="{{ url('call-detail-records/index') }}">
                    <span class="ss-dash-action-ico"><i class="download icon"></i></span>
                    <span>Скачать отчёт</span>
                    <i class="chevron right icon"></i>
                </a>
            </div>
        </div>
    </div>
</div>

<div id="ss-rec-player" class="ss-rec-player" hidden aria-hidden="true">
    <div class="ss-rec-player__inner">
        <button type="button" class="ss-rec-player__close" id="ss-rec-player-close" aria-label="Закрыть" title="Закрыть">
            <i class="close icon"></i>
        </button>
        <div class="ss-rec-player__meta">
            <strong id="ss-rec-player-title">—</strong>
            <span id="ss-rec-player-sub">—</span>
        </div>
        <div class="ss-rec-player__controls">
            <button type="button" class="ss-rec-player__btn" id="ss-rec-player-back" title="Назад 10 сек" aria-label="Назад 10 сек">
                <i class="step backward icon"></i>
            </button>
            <button type="button" class="ss-rec-player__btn ss-rec-player__btn--main" id="ss-rec-player-toggle" title="Пауза" aria-label="Пауза">
                <i class="pause icon"></i>
            </button>
            <button type="button" class="ss-rec-player__btn" id="ss-rec-player-fwd" title="Вперёд 10 сек" aria-label="Вперёд 10 сек">
                <i class="step forward icon"></i>
            </button>
        </div>
        <div class="ss-rec-player__timeline">
            <span class="ss-rec-player__time" id="ss-rec-player-cur">0:00</span>
            <input type="range" class="ss-rec-player__seek" id="ss-rec-player-seek" min="0" max="1000" value="0" step="1" aria-label="Перемотка">
            <span class="ss-rec-player__time" id="ss-rec-player-dur">0:00</span>
        </div>
    </div>
</div>
