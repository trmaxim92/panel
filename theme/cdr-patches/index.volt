<div class="ss-cdr-page">
    <div class="ss-cdr-page-head">
        <div class="ss-cdr-page-ico"><i class="list ul icon"></i></div>
        <div class="ss-cdr-page-titles">
            <h1>История вызовов</h1>
            <p>Журнал записей разговоров и лог звонков
                <a class="wiki-help-link" href="#" data-controller="CallDetailRecords" data-action="index"
                   data-content="Справка" data-variation="wide"><i class="question circle outline icon"></i></a>
            </p>
        </div>
    </div>

    <div id="cdr-filters-panel" class="ss-cdr-panel">
        <div class="ss-cdr-toolbar">
            <div class="ss-field ss-field-period">
                <label>Период</label>
                <div class="ui fluid left icon input">
                    <i class="calendar alternate outline icon"></i>
                    <input type="text" id="date-range-selector" placeholder="ДД/ММ/ГГГГ - ДД/ММ/ГГГГ" autocomplete="off">
                </div>
            </div>
        </div>

        <div class="ss-cdr-grid" id="cdr-analytics-filters">
            <div class="ss-field">
                <label>Кто звонил</label>
                <div class="ss-icon-wrap">
                    <i class="user outline icon ss-field-ico"></i>
                    <div class="ui fluid selection dropdown" id="cdr-caller-type">
                        <input type="hidden" name="cdr-caller-type" value="any">
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
                    <input type="text" id="cdr-client-number" placeholder="Укажите номер или часть" autocomplete="off">
                </div>
            </div>
            <div class="ss-field">
                <label>Куда звонил</label>
                <div class="ss-icon-wrap">
                    <i class="phone icon ss-field-ico"></i>
                    <div class="ui fluid selection dropdown" id="cdr-dst-numbers">
                        <input type="hidden" name="cdr-dst-numbers" value="any">
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
                <label>Отдел</label>
                <div class="ss-icon-wrap">
                    <i class="file alternate outline icon ss-field-ico"></i>
                    <div class="ui fluid selection dropdown" id="cdr-department">
                        <input type="hidden" name="cdr-department" value="any">
                        <i class="dropdown icon"></i>
                        <div class="default text">Все отделы</div>
                        <div class="menu">
                            <div class="item active selected" data-value="any">Все отделы</div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="ss-field">
                <label>Звонки</label>
                <div class="ss-icon-wrap">
                    <i class="phone volume icon ss-field-ico"></i>
                    <div class="ui fluid selection dropdown" id="cdr-status-filter">
                        <input type="hidden" name="cdr-status" value="ALL">
                        <i class="dropdown icon"></i>
                        <div class="default text">Все звонки</div>
                        <div class="menu">
                            <div class="item active selected" data-value="ALL">Все звонки</div>
                            <div class="item" data-value="SUCCESS">Успешные</div>
                            <div class="item" data-value="FAIL">Неуспешные</div>
                            <div class="item" data-value="ANSWERED">Отвечен</div>
                            <div class="item" data-value="NOANSWER">Пропущен</div>
                            <div class="item" data-value="BUSY">Занято</div>
                            <div class="item" data-value="FAILED">Ошибка</div>
                            <div class="item" data-value="CHANUNAVAIL">Недоступен</div>
                            <div class="item" data-value="CANCEL">Отменён</div>
                        </div>
                    </div>
                </div>
            </div>
            <div class="ss-field">
                <label>Разговор от</label>
                <div class="ss-icon-wrap">
                    <i class="clock outline icon ss-field-ico"></i>
                    <div class="ui fluid selection dropdown" id="cdr-billsec-min">
                        <input type="hidden" name="cdr-billsec-min" value="0">
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
            <div class="ss-field ss-field-span-3">
                <label>Участники</label>
                <div class="ui fluid left icon input">
                    <i class="users icon"></i>
                    <input type="text" id="cdr-participants" placeholder="Номера через запятую или пробел" autocomplete="off">
                </div>
            </div>
        </div>

        <div class="ss-cdr-actions">
            <button type="button" class="ui primary button" id="cdr-filters-apply">
                <i class="search icon"></i> Показать
            </button>
            <button type="button" class="ui basic button" id="cdr-export-csv">
                <i class="download icon"></i> CSV
            </button>
            <button type="button" class="ui basic button" id="cdr-export-xls">
                <i class="file excel outline icon"></i> Excel
            </button>
            <a href="#" class="ss-link-clear" id="cdr-filters-reset">Очистить</a>
        </div>

        <input type="hidden" id="globalsearch" value="">
        <div id="search-cdr-input" style="display:none;"></div>
    </div>

    <div class="ss-cdr-table-card" id="cdr-table-card">
        <div id="cdr-empty-state" class="ss-cdr-empty" style="display:none;" aria-hidden="true">
            <div class="ss-cdr-empty-ico"><i class="search icon"></i></div>
            <div class="ss-cdr-empty-title">Ничего не найдено</div>
            <div class="ss-cdr-empty-sub">Попробуйте изменить период поиска или ключевые слова</div>
        </div>
        <table id="cdr-table" class="ui single line unstackable table">
            <thead>
            <tr>
                <th>{{ t._('cdr_ColumnDate') }}</th>
                <th>{{ t._('cdr_ColumnFrom') }}</th>
                <th>{{ t._('cdr_ColumnTo') }}</th>
                <th>Отдел</th>
                <th>Статус</th>
                <th>Ожидание</th>
                <th>Разговор</th>
                {% if isAllowed('save') %}
                <th class="collapsing"></th>
                {% endif %}
            </tr>
            </thead>
            <tbody></tbody>
        </table>
        <div class="ss-cdr-table-footer">
            <div class="ss-cdr-page-len">
                <span class="ss-cdr-page-len-label">Записей на странице</span>
                <div class="ui compact selection dropdown" id="page-length-select">
                    <input type="hidden" name="page-length" value="auto">
                    <i class="dropdown icon"></i>
                    <div class="text">Авто</div>
                    <div class="menu">
                        <div class="item" data-value="auto">Авто</div>
                        <div class="item" data-value="25">25</div>
                        <div class="item" data-value="50">50</div>
                        <div class="item" data-value="100">100</div>
                        <div class="item" data-value="500">500</div>
                    </div>
                </div>
            </div>
            <div class="ss-cdr-pager-slot" id="cdr-pager-slot"></div>
        </div>
    </div>
</div>
