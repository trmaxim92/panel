<div class="ss-rec-page">
    <div class="ss-rec-page-head">
        <div class="ss-rec-page-ico"><i class="file audio outline icon"></i></div>
        <div class="ss-rec-page-titles">
            <h1>Записи звонков</h1>
            <p>Библиотека записей разговоров
                <a class="wiki-help-link" href="#" data-controller="CallRecordings" data-action="index"
                   data-content="Справка" data-variation="wide"><i class="question circle outline icon"></i></a>
            </p>
        </div>
    </div>

    <div class="ss-rec-storage" id="rec-storage-panel">
        <div class="ss-rec-storage-main">
            <div class="ss-rec-storage-label">Занято записями</div>
            <div class="ss-rec-storage-value" id="rec-storage-value">—</div>
            <div class="ss-rec-storage-bar" aria-hidden="true">
                <div class="ss-rec-storage-bar-fill" id="rec-storage-bar-fill" style="width:0%"></div>
            </div>
            <div class="ss-rec-storage-sub" id="rec-storage-sub">Считаем место на диске…</div>
        </div>
        <div class="ss-rec-storage-actions">
            <div class="ss-field ss-rec-retention-field">
                <label>Срок хранения / очистки</label>
                <div class="ui fluid selection dropdown" id="rec-retention-period">
                    <input type="hidden" name="rec-retention-period" value="90">
                    <i class="dropdown icon"></i>
                    <div class="default text">90 дней</div>
                    <div class="menu">
                        <div class="item" data-value="7">7 дней</div>
                        <div class="item" data-value="14">14 дней</div>
                        <div class="item" data-value="30">30 дней</div>
                        <div class="item active selected" data-value="90">90 дней</div>
                        <div class="item" data-value="180">180 дней</div>
                        <div class="item" data-value="360">360 дней</div>
                        <div class="item" data-value="1080">3 года</div>
                        <div class="item" data-value="">Без ограничения</div>
                    </div>
                </div>
            </div>
            <div class="ss-rec-storage-btns">
                <button type="button" class="ui button" id="rec-retention-save">
                    <i class="save icon"></i> Сохранить срок
                </button>
                <button type="button" class="ui primary button" id="rec-purge-btn">
                    <i class="trash alternate outline icon"></i> Очистить старые
                </button>
            </div>
            <div class="ss-rec-storage-hint" id="rec-storage-hint">
                «Очистить старые» удалит файлы записей старше выбранного срока.
            </div>
        </div>
    </div>

    <div id="rec-filters-panel" class="ss-cdr-panel ss-rec-panel">
        <div class="ss-cdr-toolbar">
            <div class="ss-field ss-field-period">
                <label>Период</label>
                <div class="ui fluid left icon input">
                    <i class="calendar alternate outline icon"></i>
                    <input type="text" id="rec-date-range" placeholder="ДД/ММ/ГГГГ - ДД/ММ/ГГГГ" autocomplete="off">
                </div>
            </div>
        </div>

        <div class="ss-cdr-grid" id="rec-analytics-filters">
            <div class="ss-field">
                <label>Кто звонил</label>
                <div class="ss-icon-wrap">
                    <i class="user outline icon ss-field-ico"></i>
                    <div class="ui fluid selection dropdown" id="rec-caller-type">
                        <input type="hidden" name="rec-caller-type" value="any">
                        <i class="dropdown icon"></i>
                        <div class="default text">Клиент или сотрудник</div>
                        <div class="menu">
                            <div class="item" data-value="client">Клиент</div>
                            <div class="item" data-value="employee">Сотрудник</div>
                            <div class="item active selected" data-value="any">Клиент или сотрудник</div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="ss-field">
                <label>Номер клиента</label>
                <div class="ui fluid left icon input">
                    <i class="search icon"></i>
                    <input type="text" id="rec-client-number" placeholder="Укажите номер или часть" autocomplete="off">
                </div>
            </div>
            <div class="ss-field">
                <label>Куда звонил</label>
                <div class="ss-icon-wrap">
                    <i class="phone icon ss-field-ico"></i>
                    <div class="ui fluid selection dropdown" id="rec-dst-numbers">
                        <input type="hidden" name="rec-dst-numbers" value="any">
                        <i class="dropdown icon"></i>
                        <div class="default text">На любой номер АТС</div>
                        <div class="menu">
                            <div class="item active selected" data-value="any">На любой номер АТС</div>
                            <div class="item" data-value="2001">Очередь: Отдел продаж (2001)</div>
                            <div class="item" data-value="2002">Очередь: Техподдержка (2002)</div>
                            <div class="item" data-value="204">204 Тряпкин Максим</div>
                            <div class="item" data-value="205">205 Коробов Тимур</div>
                            <div class="item" data-value="201">201 Smith James</div>
                            <div class="item" data-value="202">202 Brown Brandon</div>
                            <div class="item" data-value="203">203 Collins Melanie</div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="ss-field">
                <label>Разговор от</label>
                <div class="ss-icon-wrap">
                    <i class="clock outline icon ss-field-ico"></i>
                    <div class="ui fluid selection dropdown" id="rec-billsec-min">
                        <input type="hidden" name="rec-billsec-min" value="0">
                        <i class="dropdown icon"></i>
                        <div class="default text">Все</div>
                        <div class="menu">
                            <div class="item active selected" data-value="0">Все</div>
                            <div class="item" data-value="10">от 10 сек</div>
                            <div class="item" data-value="20">от 20 сек</div>
                            <div class="item" data-value="30">от 30 сек</div>
                            <div class="item" data-value="40">от 40 сек</div>
                            <div class="item" data-value="50">от 50 сек</div>
                            <div class="item" data-value="60">от 60 сек</div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="ss-cdr-actions">
            <button type="button" class="ui primary button" id="rec-filters-apply">
                <i class="search icon"></i> Показать
            </button>
            <a href="#" class="ss-link-clear" id="rec-filters-reset">Очистить</a>
        </div>
    </div>

    <div class="ss-rec-table-card" id="rec-table-card">
        <div id="rec-empty-state" class="ss-rec-empty" style="display:none;" aria-hidden="true">
            <div class="ss-rec-empty-ico"><i class="file audio outline icon"></i></div>
            <div class="ss-rec-empty-title">Нет записей</div>
            <div class="ss-rec-empty-sub">Попробуйте изменить период поиска или ключевые слова</div>
        </div>
        <table id="rec-table" class="ui single line unstackable table">
            <thead>
            <tr>
                <th class="collapsing"></th>
                <th>Дата и время</th>
                <th>Кто звонил</th>
                <th>С кем говорил</th>
                <th>Разговор</th>
                <th class="collapsing">Текст</th>
                <th class="collapsing"></th>
            </tr>
            </thead>
            <tbody></tbody>
        </table>
        <div class="ss-rec-table-footer">
            <div class="ss-rec-page-len">
                <span class="ss-rec-page-len-label">Записей на странице</span>
                <div class="ui compact selection dropdown" id="rec-page-length">
                    <input type="hidden" name="rec-page-length" value="25">
                    <i class="dropdown icon"></i>
                    <div class="text">25</div>
                    <div class="menu">
                        <div class="item" data-value="25">25</div>
                        <div class="item" data-value="50">50</div>
                        <div class="item" data-value="100">100</div>
                        <div class="item" data-value="500">500</div>
                    </div>
                </div>
            </div>
            <div class="ss-rec-count" id="rec-count-label">0 записей</div>
            <div class="ss-rec-pager-slot" id="rec-pager-slot"></div>
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
