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
