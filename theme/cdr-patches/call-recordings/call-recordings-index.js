/* global globalRootUrl, SemanticLocalization, ExtensionsAPI, moment, globalTranslate, CdrAPI, SecurityUtils, TokenManager */

/**
 * Call Recordings — flat library of CDR legs with recordingfile.
 */
const callRecordings = {
    STORAGE_KEY: 'ssCallRecordingsFilters',
    dataTable: null,
    $table: null,
    $dateRange: null,
    $callerType: null,
    $clientNumber: null,
    $dstNumbers: null,
    $billsecMin: null,
    $pageLength: null,
    activeAudio: null,

    initialize() {
        $('body').addClass('ss-rec-route');
        callRecordings.$table = $('#rec-table');
        callRecordings.$dateRange = $('#rec-date-range');
        callRecordings.$callerType = $('#rec-caller-type');
        callRecordings.$clientNumber = $('#rec-client-number');
        callRecordings.$dstNumbers = $('#rec-dst-numbers');
        callRecordings.$billsecMin = $('#rec-billsec-min');
        callRecordings.$pageLength = $('#rec-page-length');
        callRecordings.$tableCard = $('#rec-table-card');
        callRecordings.$emptyState = $('#rec-empty-state');
        callRecordings.$pagerSlot = $('#rec-pager-slot');

        try {
            ['$callerType', '$billsecMin', '$dstNumbers'].forEach((key) => {
                if (callRecordings[key] && callRecordings[key].length) {
                    callRecordings[key].dropdown();
                }
            });
            if (callRecordings.$pageLength.length) {
                callRecordings.$pageLength.dropdown({
                    onChange(pageLength) {
                        const v = parseInt(pageLength || '25', 10) || 25;
                        if (callRecordings.dataTable) {
                            callRecordings.dataTable.page.len(v).draw();
                        }
                    },
                });
            }
        } catch (e) {
            console.error('[REC] dropdown init', e);
        }

        callRecordings.applySavedState(callRecordings.loadState());

        $('#rec-filters-apply').on('click', (e) => {
            e.preventDefault();
            if (callRecordings.dataTable) {
                callRecordings.dataTable.ajax.reload();
            }
        });
        $('#rec-filters-reset').on('click', (e) => {
            e.preventDefault();
            callRecordings.resetFilters();
            if (callRecordings.dataTable) {
                callRecordings.dataTable.ajax.reload();
            }
        });

        $('#rec-filters-panel .ss-field-period .icon').on('click', () => {
            callRecordings.$dateRange.focus().trigger('click');
        });

        callRecordings.bootUi();
    },

    bootUi() {
        const state = callRecordings.loadState();
        const todayStart = moment().startOf('day');
        const todayEnd = moment().endOf('day');
        let start = todayStart.clone();
        let end = todayEnd.clone();
        if (state && state.dateFrom && state.dateTo) {
            const s = moment(state.dateFrom);
            const e = moment(state.dateTo);
            if (s.isValid()) start = s.startOf('day');
            if (e.isValid()) end = e.endOf('day');
        }

        try {
            callRecordings.initDateRange(start, end);
        } catch (err) {
            console.error('[REC] daterangepicker', err);
            callRecordings.$dateRange.val(
                `${start.format('DD/MM/YYYY')} - ${end.format('DD/MM/YYYY')}`,
            );
        }

        try {
            callRecordings.initDataTable();
        } catch (err) {
            console.error('[REC] DataTable', err);
        }

        // Widen from metadata if no saved dates
        if ((!state || !state.dateFrom) && typeof CdrAPI !== 'undefined' && CdrAPI.getMetadata) {
            CdrAPI.getMetadata({ limit: 100 }, (data) => {
                if (!data || !data.hasRecords) return;
                const s = moment(data.earliestDate);
                const e = moment(data.latestDate);
                if (!s.isValid() || !e.isValid()) return;
                const picker = callRecordings.$dateRange.data('daterangepicker');
                if (picker) {
                    picker.setStartDate(s.startOf('day'));
                    picker.setEndDate(e.endOf('day').isAfter(moment().endOf('day'))
                        ? moment().endOf('day')
                        : e.endOf('day'));
                    callRecordings.$dateRange.val(
                        `${picker.startDate.format('DD/MM/YYYY')} - ${picker.endDate.format('DD/MM/YYYY')}`,
                    );
                    if (callRecordings.dataTable) {
                        callRecordings.dataTable.ajax.reload();
                    }
                }
            });
        }
    },

    initDateRange(startDate, endDate) {
        const todayEnd = moment().endOf('day');
        let safeEnd = moment(endDate).endOf('day');
        if (safeEnd.isAfter(todayEnd)) safeEnd = todayEnd.clone();
        const safeStart = moment(startDate).startOf('day');

        const options = {
            alwaysShowCalendars: true,
            autoUpdateInput: true,
            linkedCalendars: true,
            maxDate: todayEnd.clone(),
            startDate: safeStart,
            endDate: safeEnd,
            parentEl: 'body',
            opens: 'left',
            ranges: {
                Сегодня: [moment().startOf('day'), moment().endOf('day')],
                Вчера: [
                    moment().subtract(1, 'days').startOf('day'),
                    moment().subtract(1, 'days').endOf('day'),
                ],
                Неделя: [moment().subtract(6, 'days').startOf('day'), moment().endOf('day')],
                '30 дней': [moment().subtract(29, 'days').startOf('day'), moment().endOf('day')],
            },
            locale: {
                format: 'DD/MM/YYYY',
                separator: ' - ',
                applyLabel: 'OK',
                cancelLabel: 'Отмена',
                customRangeLabel: 'Период',
                daysOfWeek: ['Вс', 'Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб'],
                monthNames: [
                    'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
                    'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь',
                ],
                firstDay: 1,
            },
        };

        try {
            const existing = callRecordings.$dateRange.data('daterangepicker');
            if (existing && existing.remove) existing.remove();
        } catch (e) { /* ignore */ }

        callRecordings.$dateRange.daterangepicker(options, () => {
            if (callRecordings.dataTable) callRecordings.dataTable.ajax.reload();
        });
        callRecordings.$dateRange.val(
            `${safeStart.format('DD/MM/YYYY')} - ${safeEnd.format('DD/MM/YYYY')}`,
        );
    },

    initDataTable() {
        if ($.fn.dataTable && $.fn.dataTable.isDataTable('#rec-table')) {
            callRecordings.$table.DataTable().clear().destroy();
            callRecordings.$table.find('tbody').empty();
        }

        const pageLen = parseInt(callRecordings.$pageLength.dropdown('get value') || '25', 10) || 25;

        callRecordings.$table.dataTable({
            serverSide: true,
            processing: true,
            ordering: false,
            pageLength: pageLen,
            columns: [
                { data: null, orderable: false, className: 'center aligned' },
                { data: 0 },
                { data: 1 },
                { data: 2 },
                { data: 3, className: 'ss-rec-duration' },
                { data: null, orderable: false, className: 'center aligned' },
            ],
            columnDefs: [{ defaultContent: '—', targets: '_all' }],
            ajax: {
                url: '/pbxcore/api/v3/cdr',
                type: 'GET',
                data(d) {
                    const params = callRecordings.buildApiParams();
                    params.limit = d.length;
                    params.offset = d.start;
                    params.sort = 'start';
                    params.order = 'DESC';
                    params.grouped = true;
                    return params;
                },
                dataSrc(json) {
                    if (!(json && json.result && json.data)) {
                        callRecordings.updateCountLabel(0);
                        callRecordings.setEmpty(true);
                        return [];
                    }
                    const groups = json.data.records || [];
                    const pagination = json.data.pagination || {};
                    const rows = callRecordings.flattenRecordings(groups);
                    // Flatten after group pagination — show flat row count for current page
                    json.recordsTotal = pagination.total || rows.length;
                    json.recordsFiltered = pagination.total || rows.length;
                    callRecordings.updateCountLabel(pagination.total || rows.length);
                    callRecordings.setEmpty(rows.length === 0);
                    callRecordings.saveState();
                    return rows;
                },
                beforeSend(xhr) {
                    if (typeof TokenManager !== 'undefined' && TokenManager.accessToken) {
                        xhr.setRequestHeader('Authorization', `Bearer ${TokenManager.accessToken}`);
                    }
                },
            },
            sDom: 'rtip',
            deferRender: true,
            language: {
                ...((typeof SemanticLocalization !== 'undefined'
                    && SemanticLocalization.dataTableLocalisation)
                    ? SemanticLocalization.dataTableLocalisation
                    : {}),
                emptyTable: 'Нет записей за выбранный период',
                zeroRecords: 'Нет записей за выбранный период',
                processing: 'Загрузка…',
            },
            createdRow(row, data) {
                const playHtml = data.playback_url
                    ? `<button type="button" class="ss-rec-play" data-play-url="${SecurityUtils.escapeHtml(data.playback_url)}" title="Слушать">
                         <i class="play icon"></i>
                         <audio class="ss-rec-audio" preload="none" src="${SecurityUtils.escapeHtml(data.playback_url)}"></audio>
                       </button>`
                    : '';
                $('td', row).eq(0).html(playHtml);

                $('td', row).eq(1).html(SecurityUtils.escapeHtml(data[0]));
                $('td', row).eq(2)
                    .html(SecurityUtils.escapeHtml(data[1]))
                    .addClass('need-update')
                    .attr('data-cdr-name', data.src_name || '');
                $('td', row).eq(3)
                    .html(SecurityUtils.escapeHtml(data[2]))
                    .addClass('need-update')
                    .attr('data-cdr-name', data.dst_name || '');
                $('td', row).eq(4).html(SecurityUtils.escapeHtml(data[3]));

                const dl = data.download_url
                    ? `<a class="ss-rec-download" href="${SecurityUtils.escapeHtml(data.download_url)}" download title="Скачать">
                         <i class="download icon"></i>
                       </a>`
                    : '';
                $('td', row).eq(5).html(dl);
            },
            drawCallback() {
                if (typeof ExtensionsAPI !== 'undefined' && ExtensionsAPI.updatePhonesRepresent) {
                    ExtensionsAPI.updatePhonesRepresent('need-update');
                }
                callRecordings.relocatePager();
                const api = callRecordings.$table.DataTable();
                const empty = !api || api.rows({ page: 'current' }).data().length === 0;
                callRecordings.setEmpty(empty);
            },
        });

        callRecordings.dataTable = callRecordings.$table.DataTable();
        callRecordings.relocatePager();

        // Play / pause via event delegation
        callRecordings.$table.off('click.recPlay').on('click.recPlay', '.ss-rec-play', function onPlay(e) {
            e.preventDefault();
            e.stopPropagation();
            const $btn = $(this);
            const audio = $btn.find('audio').get(0);
            if (!audio) return;

            if (callRecordings.activeAudio && callRecordings.activeAudio !== audio) {
                callRecordings.activeAudio.pause();
                callRecordings.activeAudio.currentTime = 0;
                $(callRecordings.activeAudio).closest('.ss-rec-play')
                    .removeClass('is-playing')
                    .find('.icon').removeClass('pause').addClass('play');
            }

            if (audio.paused) {
                // Attach bearer for media if same-origin cookie auth insufficient:
                // playback_url usually includes token query already.
                audio.play().catch((err) => console.warn('[REC] play failed', err));
                $btn.addClass('is-playing').find('.icon').removeClass('play').addClass('pause');
                callRecordings.activeAudio = audio;
                audio.onended = () => {
                    $btn.removeClass('is-playing').find('.icon').removeClass('pause').addClass('play');
                    callRecordings.activeAudio = null;
                };
            } else {
                audio.pause();
                $btn.removeClass('is-playing').find('.icon').removeClass('pause').addClass('play');
                callRecordings.activeAudio = null;
            }
        });
    },

    flattenRecordings(groups) {
        const rows = [];
        (groups || []).forEach((group) => {
            const legs = (group.records || []).filter(
                (r) => r.recordingfile && String(r.recordingfile).length > 0,
            );
            legs.forEach((rec) => {
                const billsec = Number(rec.billsec != null ? rec.billsec : (group.totalBillsec || 0)) || 0;
                const fmt = billsec < 3600 ? 'mm:ss' : 'HH:mm:ss';
                const duration = billsec > 0 ? moment.utc(billsec * 1000).format(fmt) : '—';
                const start = rec.start || group.start;
                const dateStr = start ? moment(start).format('DD-MM-YYYY HH:mm:ss') : '—';
                const src = rec.src_num || group.src_num || '';
                const dst = rec.dst_num || group.dst_num || '';
                rows.push({
                    0: dateStr,
                    1: src,
                    2: dst,
                    3: duration,
                    src_name: rec.src_name || group.src_name || '',
                    dst_name: rec.dst_name || group.dst_name || '',
                    playback_url: rec.playback_url || '',
                    download_url: rec.download_url || '',
                    id: rec.id || '',
                    DT_RowId: rec.id || group.linkedid || '',
                });
            });
        });
        return rows;
    },

    buildApiParams() {
        const params = {};
        const picker = callRecordings.$dateRange.data('daterangepicker');
        if (picker && picker.startDate && picker.endDate) {
            params.dateFrom = picker.startDate.format('YYYY-MM-DD');
            params.dateTo = picker.endDate.endOf('day').format('YYYY-MM-DD HH:mm:ss');
        } else {
            params.dateFrom = moment().format('YYYY-MM-DD');
            params.dateTo = moment().endOf('day').format('YYYY-MM-DD HH:mm:ss');
        }

        const callerType = callRecordings.$callerType.dropdown('get value') || 'any';
        if (callerType && callerType !== 'any') {
            params.callerType = callerType;
        }
        const client = (callRecordings.$clientNumber.val() || '').trim();
        if (client) {
            params.clientNumber = client;
        }
        const dstRaw = callRecordings.$dstNumbers.dropdown('get value');
        const dstVal = Array.isArray(dstRaw) ? (dstRaw[0] || '') : String(dstRaw || '').trim();
        if (dstVal && dstVal !== 'any' && dstVal !== '__ALL__') {
            params.dstNumbers = dstVal;
        }
        const billsecMin = parseInt(callRecordings.$billsecMin.dropdown('get value') || '0', 10) || 0;
        if (billsecMin > 0) {
            params.billsecMin = billsecMin;
        }
        return params;
    },

    updateCountLabel(n) {
        const count = Number(n) || 0;
        let text = `${count} записей`;
        if (count === 1) text = '1 запись';
        else if (count >= 2 && count <= 4) text = `${count} записи`;
        $('#rec-count-label').text(text);
    },

    setEmpty(isEmpty) {
        if (!callRecordings.$tableCard || !callRecordings.$tableCard.length) return;
        callRecordings.$tableCard.toggleClass('is-empty', !!isEmpty);
        if (callRecordings.$emptyState && callRecordings.$emptyState.length) {
            callRecordings.$emptyState.toggle(!!isEmpty).attr('aria-hidden', isEmpty ? 'false' : 'true');
        }
    },

    relocatePager() {
        const $wrap = callRecordings.$table.closest('.dataTables_wrapper');
        if (!$wrap.length || !callRecordings.$pagerSlot || !callRecordings.$pagerSlot.length) return;
        const $info = $wrap.find('.dataTables_info');
        const $paginate = $wrap.find('.dataTables_paginate');
        if ($info.length) callRecordings.$pagerSlot.append($info);
        if ($paginate.length) callRecordings.$pagerSlot.append($paginate);
    },

    loadState() {
        try {
            const raw = sessionStorage.getItem(callRecordings.STORAGE_KEY);
            return raw ? JSON.parse(raw) : null;
        } catch (e) {
            return null;
        }
    },

    saveState() {
        try {
            const picker = callRecordings.$dateRange.data('daterangepicker');
            const state = {
                dateFrom: picker ? picker.startDate.format('YYYY-MM-DD') : null,
                dateTo: picker ? picker.endDate.format('YYYY-MM-DD') : null,
                callerType: callRecordings.$callerType.dropdown('get value') || 'any',
                clientNumber: callRecordings.$clientNumber.val() || '',
                billsecMin: callRecordings.$billsecMin.dropdown('get value') || '0',
            };
            sessionStorage.setItem(callRecordings.STORAGE_KEY, JSON.stringify(state));
        } catch (e) { /* ignore */ }
    },

    applySavedState(state) {
        if (!state) return;
        if (state.callerType) callRecordings.$callerType.dropdown('set selected', state.callerType);
        if (state.clientNumber !== undefined) callRecordings.$clientNumber.val(state.clientNumber || '');
        if (state.billsecMin !== undefined) {
            callRecordings.$billsecMin.dropdown('set selected', String(state.billsecMin));
        }
    },

    resetFilters() {
        callRecordings.$callerType.dropdown('set selected', 'any');
        callRecordings.$clientNumber.val('');
        callRecordings.$billsecMin.dropdown('set selected', '0');
        if (callRecordings.$dstNumbers.length) {
            callRecordings.$dstNumbers.dropdown('set selected', 'any');
        }
        const start = moment().startOf('day');
        const end = moment().endOf('day');
        const picker = callRecordings.$dateRange.data('daterangepicker');
        if (picker) {
            picker.setStartDate(start);
            picker.setEndDate(end);
        }
        callRecordings.$dateRange.val(
            `${start.format('DD/MM/YYYY')} - ${end.format('DD/MM/YYYY')}`,
        );
        try {
            sessionStorage.removeItem(callRecordings.STORAGE_KEY);
        } catch (e) { /* ignore */ }
    },
};

$(document).ready(() => {
    callRecordings.initialize();
});
