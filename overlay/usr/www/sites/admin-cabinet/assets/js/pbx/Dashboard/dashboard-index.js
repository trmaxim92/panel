/* global moment, TokenManager, globalRootUrl */

/**
 * ATC Dashboard — KPIs, SVG charts, recent calls, queues.
 * Note: MikoPBX ships jQuery 2.2.4 — Deferred has no .catch(); use native Promises.
 */
const dashApp = {
    range: 'today',
    cache: { today: null, yesterday: null, week: null, month: null },

    initialize() {
        $('body').addClass('ss-dash-route');
        $('#page-header').hide();

        $('#dash-range-tabs').on('click', 'button', (e) => {
            const $btn = $(e.currentTarget);
            $('#dash-range-tabs button').removeClass('is-active');
            $btn.addClass('is-active');
            dashApp.range = $btn.data('range') || 'today';
            dashApp.renderDynamics();
        });

        dashApp.load();
    },

    authHeaders() {
        const h = {};
        if (typeof TokenManager !== 'undefined' && TokenManager.accessToken) {
            h.Authorization = `Bearer ${TokenManager.accessToken}`;
        }
        return h;
    },

    waitForToken(maxMs) {
        const deadline = Date.now() + (maxMs || 3000);
        return new Promise((resolve) => {
            const tick = () => {
                if (typeof TokenManager !== 'undefined' && TokenManager.accessToken) {
                    resolve(true);
                    return;
                }
                if (Date.now() >= deadline) {
                    resolve(false);
                    return;
                }
                setTimeout(tick, 50);
            };
            tick();
        });
    },

    fetchCdr(dateFrom, dateTo) {
        return new Promise((resolve) => {
            $.ajax({
                url: '/pbxcore/api/v3/cdr',
                type: 'GET',
                dataType: 'json',
                data: {
                    dateFrom,
                    dateTo,
                    limit: 2000,
                    offset: 0,
                    sort: 'start',
                    order: 'DESC',
                    grouped: true,
                },
                headers: dashApp.authHeaders(),
                success(json) {
                    if (json && json.result && json.data) {
                        resolve(json.data.records || []);
                    } else {
                        resolve([]);
                    }
                },
                error() {
                    resolve([]);
                },
            });
        });
    },

    async load() {
        try {
            await dashApp.waitForToken(4000);

            const today = moment().format('YYYY-MM-DD');
            const yesterday = moment().subtract(1, 'day').format('YYYY-MM-DD');
            const weekFrom = moment().subtract(6, 'day').format('YYYY-MM-DD');
            const monthFrom = moment().subtract(29, 'day').format('YYYY-MM-DD');
            const end = moment().endOf('day').format('YYYY-MM-DD HH:mm:ss');

            const [todayRecs, yRecs, weekRecs, monthRecs] = await Promise.all([
                dashApp.fetchCdr(today, end),
                dashApp.fetchCdr(yesterday, moment(yesterday).endOf('day').format('YYYY-MM-DD HH:mm:ss')),
                dashApp.fetchCdr(weekFrom, end),
                dashApp.fetchCdr(monthFrom, end),
            ]);

            dashApp.cache.today = todayRecs;
            dashApp.cache.yesterday = yRecs;
            dashApp.cache.week = weekRecs;
            dashApp.cache.month = monthRecs;

            $('#dash-updated-at').text(`обновлено ${moment().format('HH:mm')}`);

            dashApp.renderKpis();
            dashApp.renderDynamics();
            dashApp.renderDonut();
            dashApp.renderRecent();
            dashApp.renderQueues();
        } catch (err) {
            console.error('[DASH] load failed', err);
            dashApp.cache.today = [];
            dashApp.cache.yesterday = [];
            dashApp.cache.week = [];
            dashApp.cache.month = [];
            dashApp.renderKpis();
            dashApp.renderDynamics();
            dashApp.renderDonut();
            dashApp.renderRecent();
            dashApp.renderQueues();
            $('#dash-updated-at').text('ошибка загрузки');
        }
    },

    classify(group) {
        const disp = String(group.disposition || '').toUpperCase().replace(/\s+/g, '');
        const missed = disp && disp !== 'ANSWERED' && disp !== 'ANSWER';
        const src = String(group.src_num || '');
        const dst = String(group.dst_num || group.did || '');
        const srcExt = /^\d{2,4}$/.test(src);
        const incoming = !srcExt || (group.did && String(group.did).length > 0 && !srcExt);
        return {
            missed,
            incoming: !!incoming,
            outgoing: !incoming,
            billsec: Number(group.totalBillsec || 0) || 0,
            start: group.start,
            src,
            dst,
            srcName: group.src_name || '',
            dstName: group.dst_name || '',
            disposition: disp,
        };
    },

    summarize(recs) {
        let total = 0; let inn = 0; let out = 0; let miss = 0;
        (recs || []).forEach((g) => {
            const c = dashApp.classify(g);
            total += 1;
            if (c.missed) miss += 1;
            if (c.incoming) inn += 1;
            else out += 1;
        });
        return { total, inn, out, miss };
    },

    pctChange(cur, prev) {
        if (prev === 0) {
            if (cur === 0) return { text: '0%', cls: 'is-flat' };
            return { text: '↑ +100%', cls: 'is-up' };
        }
        const p = Math.round(((cur - prev) / prev) * 100);
        if (p > 0) return { text: `↑ +${p}%`, cls: 'is-up' };
        if (p < 0) return { text: `↓ ${p}%`, cls: 'is-down' };
        return { text: '0%', cls: 'is-flat' };
    },

    renderKpis() {
        const t = dashApp.summarize(dashApp.cache.today);
        const y = dashApp.summarize(dashApp.cache.yesterday);
        const map = {
            total: [t.total, y.total],
            in: [t.inn, y.inn],
            out: [t.out, y.out],
            miss: [t.miss, y.miss],
        };
        Object.keys(map).forEach((key) => {
            const $card = $(`.ss-dash-kpi[data-kpi="${key}"]`);
            const [cur, prev] = map[key];
            $card.find('[data-role="value"]').text(String(cur));
            const tr = dashApp.pctChange(cur, prev);
            $card.find('[data-role="trend"]').attr('class', `ss-dash-kpi-trend ${tr.cls}`).text(tr.text);
        });
    },

    bucketsForRange() {
        if (dashApp.range === '7d') {
            return dashApp.dayBuckets(dashApp.cache.week, 7);
        }
        if (dashApp.range === '30d') {
            return dashApp.dayBuckets(dashApp.cache.month, 30);
        }
        return dashApp.hourBuckets(dashApp.cache.today);
    },

    hourBuckets(recs) {
        const labels = [];
        const inn = [];
        const out = [];
        const miss = [];
        for (let h = 0; h < 24; h++) {
            labels.push(`${String(h).padStart(2, '0')}:00`);
            inn.push(0);
            out.push(0);
            miss.push(0);
        }
        (recs || []).forEach((g) => {
            const c = dashApp.classify(g);
            const h = moment(g.start).hour();
            if (h >= 0 && h < 24) {
                if (c.incoming) inn[h] += 1;
                else out[h] += 1;
                if (c.missed) miss[h] += 1;
            }
        });
        return { labels, inn, out, miss };
    },

    dayBuckets(recs, days) {
        const labels = [];
        const inn = [];
        const out = [];
        const miss = [];
        const index = {};
        for (let i = days - 1; i >= 0; i--) {
            const d = moment().subtract(i, 'day');
            const key = d.format('YYYY-MM-DD');
            index[key] = labels.length;
            labels.push(d.format('DD.MM'));
            inn.push(0);
            out.push(0);
            miss.push(0);
        }
        (recs || []).forEach((g) => {
            const key = moment(g.start).format('YYYY-MM-DD');
            if (index[key] === undefined) return;
            const c = dashApp.classify(g);
            if (c.incoming) inn[index[key]] += 1;
            else out[index[key]] += 1;
            if (c.missed) miss[index[key]] += 1;
        });
        return { labels, inn, out, miss };
    },

    renderDynamics() {
        const { labels, inn, out, miss } = dashApp.bucketsForRange();
        const w = 640;
        const h = 220;
        const pad = { t: 16, r: 12, b: 28, l: 32 };
        const max = Math.max(1, ...inn, ...out, ...miss);
        const n = labels.length;
        const x = (i) => pad.l + (i / Math.max(1, n - 1)) * (w - pad.l - pad.r);
        const y = (v) => pad.t + (1 - v / max) * (h - pad.t - pad.b);

        const path = (arr) => arr.map((v, i) => `${i === 0 ? 'M' : 'L'}${x(i).toFixed(1)},${y(v).toFixed(1)}`).join(' ');
        const area = (arr) => `${path(arr)} L${x(n - 1).toFixed(1)},${(h - pad.b).toFixed(1)} L${x(0).toFixed(1)},${(h - pad.b).toFixed(1)} Z`;

        const grid = [];
        for (let g = 0; g <= 4; g++) {
            const gy = pad.t + (g / 4) * (h - pad.t - pad.b);
            grid.push(`<line x1="${pad.l}" y1="${gy}" x2="${w - pad.r}" y2="${gy}" stroke="#EEF1F5" stroke-width="1"/>`);
        }

        const labelStep = n > 12 ? Math.ceil(n / 6) : (n > 8 ? 2 : 1);
        const xLabels = labels.map((lb, i) => {
            if (i % labelStep !== 0 && i !== n - 1) return '';
            return `<text x="${x(i)}" y="${h - 8}" text-anchor="middle" fill="#8B90A0" font-size="11" font-weight="600">${lb}</text>`;
        }).join('');

        const svg = `
<svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="none" xmlns="http://www.w3.org/2000/svg">
  ${grid.join('')}
  <path d="${area(inn)}" fill="rgba(34,197,94,0.10)"></path>
  <path d="${area(out)}" fill="rgba(139,92,246,0.08)"></path>
  <path d="${area(miss)}" fill="rgba(229,57,53,0.08)"></path>
  <path d="${path(inn)}" fill="none" stroke="#22C55E" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"></path>
  <path d="${path(out)}" fill="none" stroke="#8B5CF6" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"></path>
  <path d="${path(miss)}" fill="none" stroke="#E53935" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="5 4"></path>
  ${xLabels}
</svg>`;
        $('#dash-line-chart').html(svg);
    },

    renderDonut() {
        const s = dashApp.summarize(dashApp.cache.today);
        const parts = [
            { key: 'in', label: 'Входящие', value: s.inn, color: '#22C55E' },
            { key: 'out', label: 'Исходящие', value: s.out, color: '#8B5CF6' },
            { key: 'miss', label: 'Пропущенные', value: s.miss, color: '#E53935' },
        ];
        const total = Math.max(1, s.total);
        const r = 54;
        const c = 2 * Math.PI * r;
        let offset = 0;
        const circles = parts.map((p) => {
            const len = (p.value / total) * c;
            const el = `<circle cx="70" cy="70" r="${r}" fill="none" stroke="${p.color}" stroke-width="12"
              stroke-dasharray="${len} ${c - len}" stroke-dashoffset="${-offset}"
              transform="rotate(-90 70 70)" stroke-linecap="round"></circle>`;
            offset += len;
            return el;
        }).join('');

        $('#dash-donut').html(`
          <svg viewBox="0 0 140 140">${circles}</svg>
          <div class="ss-dash-donut-center"><strong>${s.total}</strong><span>всего</span></div>
        `);

        $('#dash-donut-legend').html(parts.map((p) => {
            const pct = s.total ? ((p.value / s.total) * 100).toFixed(1) : '0.0';
            return `<div class="ss-dash-donut-item">
              <i class="ss-dot" style="background:${p.color}"></i>
              <span>${p.label}</span>
              <span class="pct">${pct}%</span>
              <span class="cnt">${p.value}</span>
            </div>`;
        }).join(''));
    },

    initials(name, num) {
        const n = String(name || '').trim();
        if (n) {
            const parts = n.split(/\s+/).filter(Boolean);
            return ((parts[0] || '')[0] || '') + ((parts[1] || '')[0] || '');
        }
        return String(num || '?').slice(-2);
    },

    colorFor(seed) {
        const colors = ['#2F6FED', '#7C3AED', '#E53935', '#0D9488', '#C45C12', '#2563EB'];
        let h = 0;
        const s = String(seed || 'x');
        for (let i = 0; i < s.length; i++) h = (h + s.charCodeAt(i) * (i + 1)) % colors.length;
        return colors[h];
    },

    fmtDur(sec) {
        const s = Number(sec) || 0;
        if (s <= 0) return '—';
        const m = Math.floor(s / 60);
        const r = s % 60;
        return `${m}:${String(r).padStart(2, '0')}`;
    },

    renderRecent() {
        const rows = (dashApp.cache.today || []).slice(0, 8);
        if (!rows.length) {
            $('#dash-recent-body').html('<tr><td colspan="6" class="ss-dash-loading">Нет звонков за сегодня</td></tr>');
            return;
        }
        const html = rows.map((g) => {
            const c = dashApp.classify(g);
            const name = c.incoming ? (c.srcName || c.src) : (c.dstName || c.dst);
            const num = c.incoming ? c.src : c.dst;
            const ok = !c.missed;
            const ini = dashApp.initials(c.incoming ? c.srcName : c.dstName, num).toUpperCase();
            return `<tr>
              <td>${moment(g.start).format('DD.MM.YYYY HH:mm')}</td>
              <td><span class="ss-dash-client"><span class="ss-dash-ava" style="background:${dashApp.colorFor(name)}">${ini || '—'}</span>${dashApp.esc(name || '—')}</span></td>
              <td>${dashApp.esc(num || '—')}</td>
              <td><span class="ss-dash-type ${c.incoming ? 'is-in' : 'is-out'}"><i class="${c.incoming ? 'sign in' : 'sign out'} icon"></i>${c.incoming ? 'Вход.' : 'Исх.'}</span></td>
              <td><span class="ss-dash-st ${ok ? 'is-ok' : 'is-miss'}">${ok ? 'Успешный' : 'Пропущен'}</span></td>
              <td>${dashApp.fmtDur(c.billsec)}</td>
            </tr>`;
        }).join('');
        $('#dash-recent-body').html(html);
    },

    renderQueues() {
        const queues = [
            { id: '2001', name: 'Отдел продаж' },
            { id: '2002', name: 'Техподдержка' },
            { id: 'other', name: 'Прочие' },
        ];
        const counts = { '2001': 0, '2002': 0, other: 0 };
        (dashApp.cache.today || []).forEach((g) => {
            const dst = String(g.dst_num || '');
            if (dst === '2001') counts['2001'] += 1;
            else if (dst === '2002') counts['2002'] += 1;
            else counts.other += 1;
        });
        const max = Math.max(1, ...Object.values(counts));
        const total = Math.max(1, Object.values(counts).reduce((a, b) => a + b, 0));
        $('#dash-queues').html(queues.map((q) => {
            const v = counts[q.id] || 0;
            const pct = Math.round((v / total) * 100);
            const w = Math.round((v / max) * 100);
            return `<div class="ss-dash-queue-row">
              <div class="ss-dash-queue-top"><b>${q.name}</b><span>${v} · ${pct}%</span></div>
              <div class="ss-dash-queue-bar"><i style="width:${w}%"></i></div>
            </div>`;
        }).join(''));
    },

    esc(s) {
        return String(s || '')
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;');
    },
};

$(document).ready(() => {
    dashApp.initialize();
});
