/* global globalRootUrl, SemanticLocalization, ExtensionsAPI, moment, globalTranslate, CdrAPI, SecurityUtils, TokenManager, StorageAPI, UserMessage */

/**
 * Call Recordings — flat library of CDR legs with recordingfile.
 */
const callRecordings = {
    STORAGE_KEY: 'ssCallRecordingsFilters',
    RETENTION_OPTIONS: ['7', '14', '30', '90', '180', '360', '1080', ''],
    dataTable: null,
    $table: null,
    $dateRange: null,
    $callerType: null,
    $clientNumber: null,
    $dstNumbers: null,
    $billsecMin: null,
    $pageLength: null,
    $retention: null,
    activeAudio: null,
    purging: false,

    initialize() {
        $('body').addClass('ss-rec-route');
        callRecordings.$table = $('#rec-table');
        callRecordings.$dateRange = $('#rec-date-range');
        callRecordings.$callerType = $('#rec-caller-type');
        callRecordings.$clientNumber = $('#rec-client-number');
        callRecordings.$dstNumbers = $('#rec-dst-numbers');
        callRecordings.$billsecMin = $('#rec-billsec-min');
        callRecordings.$pageLength = $('#rec-page-length');
        callRecordings.$retention = $('#rec-retention-period');
        callRecordings.$tableCard = $('#rec-table-card');
        callRecordings.$emptyState = $('#rec-empty-state');
        callRecordings.$pagerSlot = $('#rec-pager-slot');

        try {
            ['$callerType', '$billsecMin', '$dstNumbers'].forEach((key) => {
                if (callRecordings[key] && callRecordings[key].length) {
                    callRecordings[key].dropdown();
                }
            });
            if (callRecordings.$retention.length) {
                callRecordings.$retention.dropdown({
                    onChange() {
                        callRecordings.updatePurgeHint();
                    },
                });
            }
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

        $('#rec-retention-save').on('click', (e) => {
            e.preventDefault();
            callRecordings.saveRetention();
        });
        $('#rec-purge-btn').on('click', (e) => {
            e.preventDefault();
            callRecordings.purgeOldRecordings();
        });

        callRecordings.loadStorageUsage();
        callRecordings.loadRetentionSetting();
        callRecordings.bootUi();
    },

    formatSizeMb(sizeInMb) {
        const n = Number(sizeInMb) || 0;
        if (n < 1024) return `${n.toFixed(n < 10 ? 1 : 0)} МБ`;
        return `${(n / 1024).toFixed(n < 10240 ? 1 : 0)} ГБ`;
    },

    formatBytes(bytes) {
        const b = Number(bytes) || 0;
        if (b < 1024) return `${b} Б`;
        if (b < 1024 * 1024) return `${(b / 1024).toFixed(1)} КБ`;
        return callRecordings.formatSizeMb(b / (1024 * 1024));
    },

    loadStorageUsage() {
        const $value = $('#rec-storage-value');
        const $sub = $('#rec-storage-sub');
        const $fill = $('#rec-storage-bar-fill');
        if (typeof StorageAPI === 'undefined' || !StorageAPI.getUsage) {
            $value.text('—');
            $sub.text('API хранилища недоступен');
            return;
        }
        StorageAPI.getUsage((response) => {
            if (!response || !response.result || !response.data) {
                $value.text('—');
                $sub.text(response && response.data && response.data.pending
                    ? 'Идёт подсчёт… обновите страницу через минуту'
                    : 'Не удалось получить данные о диске');
                return;
            }
            const data = response.data;
            if (data.pending) {
                $value.text('…');
                $sub.text('Идёт подсчёт…');
                setTimeout(() => callRecordings.loadStorageUsage(), 4000);
                return;
            }
            const cat = (data.categories && data.categories.call_recordings) || {};
            const recMb = Number(cat.size) || 0;
            const usedMb = Number(data.used_space) || 0;
            const totalMb = Number(data.total_size) || 0;
            const pctOfDisk = totalMb > 0 ? Math.min(100, (recMb / totalMb) * 100) : 0;
            const pctUsed = totalMb > 0 ? Math.min(100, (usedMb / totalMb) * 100) : 0;

            $value.text(callRecordings.formatSizeMb(recMb));
            $fill.css('width', `${Math.max(2, pctOfDisk).toFixed(1)}%`);
            $sub.text(
                `Диск занят на ${pctUsed.toFixed(0)}% · всего ${callRecordings.formatSizeMb(totalMb)}`
                + (cat.percentage != null ? ` · записи ${Number(cat.percentage).toFixed(1)}%` : ''),
            );
        });
    },

    loadRetentionSetting() {
        if (typeof StorageAPI === 'undefined' || !StorageAPI.get) return;
        StorageAPI.get((response) => {
            if (!response || !response.result || !response.data) return;
            const period = response.data.PBXRecordSavePeriod;
            const val = period === null || period === undefined ? '' : String(period);
            if (callRecordings.RETENTION_OPTIONS.indexOf(val) !== -1) {
                callRecordings.$retention.dropdown('set selected', val);
            } else if (val && callRecordings.RETENTION_OPTIONS.indexOf(val) === -1) {
                // keep closest or set raw
                callRecordings.$retention.dropdown('set selected', '90');
            }
            callRecordings.updatePurgeHint();
        });
    },

    updatePurgeHint() {
        const days = callRecordings.$retention.dropdown('get value');
        const $hint = $('#rec-storage-hint');
        const $purge = $('#rec-purge-btn');
        if (!days) {
            $hint.text('Без ограничения: автоочистка отключена. Для ручной очистки выберите срок.');
            $purge.prop('disabled', true).addClass('disabled');
        } else {
            $hint.text(`«Очистить старые» удалит файлы записей старше ${days} дн. Срок хранения синхронизируется с разделом «Хранилище».`);
            $purge.prop('disabled', false).removeClass('disabled');
        }
    },

    saveRetention() {
        const days = callRecordings.$retention.dropdown('get value');
        if (typeof StorageAPI === 'undefined' || !StorageAPI.patch) {
            callRecordings.notify(false, 'API хранилища недоступен');
            return;
        }
        const $btn = $('#rec-retention-save').addClass('loading disabled');
        StorageAPI.patch({ PBXRecordSavePeriod: days }, (response) => {
            $btn.removeClass('loading disabled');
            if (response && response.result) {
                callRecordings.notify(true, 'Срок хранения сохранён');
                callRecordings.updatePurgeHint();
            } else {
                callRecordings.notify(false, (response && response.messages && response.messages.error)
                    ? response.messages.error.join(', ')
                    : 'Не удалось сохранить срок');
            }
        });
    },

    purgeOldRecordings() {
        const days = callRecordings.$retention.dropdown('get value');
        if (!days) {
            callRecordings.notify(false, 'Выберите срок очистки');
            return;
        }
        if (callRecordings.purging) return;
        const ok = window.confirm(
            `Удалить все файлы записей старше ${days} дней?\nЭто действие нельзя отменить.`,
        );
        if (!ok) return;

        callRecordings.purging = true;
        const $btn = $('#rec-purge-btn').addClass('loading disabled');
        $.ajax({
            url: `${globalRootUrl}call-recordings/purge`,
            method: 'POST',
            dataType: 'json',
            data: { days },
            success(res) {
                callRecordings.purging = false;
                $btn.removeClass('loading disabled');
                if (res && res.success) {
                    const freed = res.data && res.data.freedBytes
                        ? ` · освобождено ${callRecordings.formatBytes(res.data.freedBytes)}`
                        : '';
                    callRecordings.notify(true, (res.message || 'Готово') + freed);
                    callRecordings.loadStorageUsage();
                    if (callRecordings.dataTable) {
                        callRecordings.dataTable.ajax.reload();
                    }
                } else {
                    callRecordings.notify(false, (res && res.message) || 'Ошибка очистки');
                }
                callRecordings.updatePurgeHint();
            },
            error() {
                callRecordings.purging = false;
                $btn.removeClass('loading disabled');
                callRecordings.notify(false, 'Ошибка запроса очистки');
                callRecordings.updatePurgeHint();
            },
        });
    },

    notify(ok, text) {
        if (typeof UserMessage !== 'undefined' && UserMessage.showMultiString) {
            UserMessage.showMultiString(text, ok ? '' : 'Ошибка');
            return;
        }
        if (ok) {
            console.info('[REC]', text);
        } else {
            console.error('[REC]', text);
        }
        window.alert(text);
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
                { data: null, orderable: false, className: 'center aligned ss-rec-tx-col' },
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

                const tx = data.linkedid
                    ? `<span class="ss-rec-tx" data-linkedid="${SecurityUtils.escapeHtml(data.linkedid)}" title="Проверяем расшифровку…">—</span>`
                    : '—';
                $('td', row).eq(5).html(tx);

                const dl = data.download_url
                    ? `<a class="ss-rec-download" href="${SecurityUtils.escapeHtml(data.download_url)}" download title="Скачать">
                         <i class="download icon"></i>
                       </a>`
                    : '';
                $('td', row).eq(6).html(dl);
            },
            drawCallback() {
                if (typeof ExtensionsAPI !== 'undefined' && ExtensionsAPI.updatePhonesRepresent) {
                    ExtensionsAPI.updatePhonesRepresent('need-update');
                }
                callRecordings.relocatePager();
                const api = callRecordings.$table.DataTable();
                const empty = !api || api.rows({ page: 'current' }).data().length === 0;
                callRecordings.setEmpty(empty);
                callRecordings.refreshTranscriptBadges();
            },
        });

        callRecordings.dataTable = callRecordings.$table.DataTable();
        callRecordings.relocatePager();

        callRecordings.$table.off('click.recTx').on('click.recTx', '.ss-rec-tx.is-ready', function onTx(e) {
            e.preventDefault();
            e.stopPropagation();
            const $el = $(this);
            const publicId = String($el.attr('data-public-id') || '').trim();
            const linkedid = String($el.attr('data-linkedid') || '').trim();
            if (!publicId) return;
            const row = callRecordings.dataTable ? callRecordings.dataTable.row($el.closest('tr')).data() : null;
            const call = {
                date: row ? String(row[0] || '') : '',
                source: row ? String(row[1] || '') : '',
                sourceName: row ? String(row.src_name || '') : '',
                destination: row ? String(row[2] || '') : '',
                destinationName: row ? String(row.dst_name || '') : '',
                duration: row ? String(row[3] || '') : '',
            };
            const cdr = window.ModuleCloudSpeechToTextCdr;
            if (cdr && typeof cdr.openTranscriptByPublicId === 'function') {
                if (cdr.openTranscriptByPublicId(linkedid || publicId, publicId, call)) {
                    return;
                }
            }
        });

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
                    linkedid: group.linkedid || rec.linkedid || '',
                    id: rec.id || '',
                    DT_RowId: rec.id || group.linkedid || '',
                });
            });
        });
        return rows;
    },

    refreshTranscriptBadges() {
        const ids = [];
        callRecordings.$table.find('.ss-rec-tx[data-linkedid]').each(function collect() {
            const id = String($(this).attr('data-linkedid') || '').trim();
            if (id && ids.indexOf(id) === -1) ids.push(id);
        });
        if (!ids.length) return;

        const lookupUrl = '/pbxcore/api/v3/module-cloud-speech-to-text/cdr-transcript-lookups';
        for (let offset = 0; offset < ids.length; offset += 100) {
            const batch = ids.slice(offset, offset + 100);
            $.ajax({
                url: lookupUrl,
                method: 'POST',
                contentType: 'application/json; charset=utf-8',
                dataType: 'json',
                data: JSON.stringify({ call_ids: batch }),
                beforeSend(xhr) {
                    if (typeof TokenManager !== 'undefined' && TokenManager.accessToken) {
                        xhr.setRequestHeader('Authorization', `Bearer ${TokenManager.accessToken}`);
                    }
                },
            }).done((response) => {
                const data = (response && response.data) || response || {};
                const map = (data && data.transcript_map) || {};
                batch.forEach((callId) => {
                    const publicId = map[callId] ? String(map[callId]) : '';
                    const $el = callRecordings.$table.find('.ss-rec-tx').filter(function matchCall() {
                        return String($(this).attr('data-linkedid') || '') === callId;
                    });
                    if (!$el.length) return;
                    if (/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(publicId)) {
                        $el
                            .addClass('is-ready')
                            .attr('data-public-id', publicId)
                            .attr('title', 'Открыть расшифровку')
                            .html('<i class="file alternate outline icon"></i>');
                    } else {
                        $el.removeClass('is-ready').removeAttr('data-public-id').attr('title', 'Нет расшифровки').text('—');
                    }
                });
            });
        }
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
