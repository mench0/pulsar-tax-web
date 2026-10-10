// Pulsar Tax — фронтенд без сборки и зависимостей.

import { LANGS, t, setLang, getLang, browserLang } from './i18n.js';
import { API_BASE } from './config.js';

const app = document.getElementById('app');
const topbar = document.getElementById('topbar-controls');
const tabsEl = document.getElementById('tabs');
const footerEl = document.getElementById('footer');
const toastEl = document.getElementById('toast');

const REGIMES = ['MICRO', 'TURNOVER', 'GENERAL'];
const ACTIVITIES = ['SERVICES', 'TRADE', 'HIGH_TECH', 'CONSULTING', 'ENGINEERING', 'MARKETING', 'DESIGN',
  'TRANSLATION', 'LEGAL', 'ACCOUNTING', 'AGENCY', 'CUSTOM'];
const CURRENCIES = ['AMD', 'USD', 'EUR', 'RUB', 'GBP', 'GEL'];
const LANG_KEY = 'pulsar.lang';

const state = { year: new Date().getFullYear(), me: null };
/** Запросы текущей страницы. При переходе на другую они отменяются, чтобы медленный ответ не перерисовал экран. */
let pageRequests = new AbortController();

// ---------- Утилиты ----------

const locale = () => ({ ru: 'ru-RU', en: 'en-GB', hy: 'hy-AM' })[getLang()];
const num = (v, digits = 2) => new Intl.NumberFormat(locale(), { maximumFractionDigits: digits }).format(Number(v));
const fmt = (v) => (v === null || v === undefined ? '—' : `${num(v)} ֏`);
const fmtDate = (s) => {
  if (!s) return '';
  const [y, m, d] = s.split('-');
  return `${d}.${m}.${y}`;
};
/** Сегодня по Еревану в формате ГГГГ-ММ-ДД. */
const today = () => new Intl.DateTimeFormat('en-CA', { timeZone: 'Asia/Yerevan' }).format(new Date());

/** Экранирует текст перед вставкой в HTML. */
function esc(value) {
  return String(value ?? '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

class AuthError extends Error {}

/** Полный адрес API: фронтенд и API живут на разных адресах. */
const apiUrl = (path) => `${API_BASE}${path}`;

async function api(method, path, body) {
  const res = await fetch(apiUrl(path), {
    method,
    credentials: 'include', // cookie сессии: API на другом адресе
    headers: body ? { 'Content-Type': 'application/json' } : {},
    body: body ? JSON.stringify(body) : undefined,
    signal: method === 'GET' ? pageRequests.signal : undefined,
  });
  if (res.status === 204) return null;
  const data = await res.json().catch((e) => {
    if (e.name === 'AbortError') throw e; // переход на другую страницу во время чтения ответа
    return {};
  });
  if (res.status === 401 && !path.startsWith('/api/auth/')) throw new AuthError(t('auth.expired'));
  if (!res.ok) throw new Error(data.error || `Error ${res.status}`);
  return data;
}

let toastTimer;
function toast(message, isError = false) {
  toastEl.textContent = message;
  toastEl.classList.toggle('error', isError);
  toastEl.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (toastEl.hidden = true), 3500);
}

/** Выполняет действие и показывает ошибку; при закончившейся сессии возвращает на вход. */
async function guarded(fn) {
  try {
    await fn();
  } catch (e) {
    if (e.name === 'AbortError') return; // страницу уже сменили
    if (e instanceof AuthError) {
      state.me = null;
      renderChrome();
      authView('login');
    }
    toast(e.message, true);
  }
}

function formData(form) {
  return Object.fromEntries(new FormData(form).entries());
}

const options = (values, label, selected) =>
  values.map((v) => `<option value="${esc(v)}" ${v === selected ? 'selected' : ''}>${esc(label(v))}</option>`).join('');

const warningText = (w) => t(`warn.${w.code}`, {
  ...w.params,
  activity: w.params.activity ? t(`activity.${w.params.activity}`) : '',
  regime: w.params.regime ? t(`regime.${w.params.regime}`) : '',
});
const deadlineText = (d) => t(`deadline.${d.code}`, d.params);

async function copy(text) {
  try {
    await navigator.clipboard.writeText(text);
    toast(t('common.copied'));
  } catch {
    prompt('', text);
  }
}

// ---------- Каркас: вкладки, год, язык ----------

const VIEWS = { overview, incomes, import: importView, report, invoices, settings, invoice: invoiceView };
const TABS = ['overview', 'incomes', 'report', 'invoices', 'settings'];

function currentRoute() {
  const [view, id] = location.hash.replace(/^#\/?/, '').split('/');
  return { view: VIEWS[view] ? view : 'overview', id };
}

function renderChrome() {
  document.title = 'Pulsar Tax';
  footerEl.textContent = t('app.footer');
  const { view } = currentRoute();
  const parent = { invoice: 'invoices', import: 'incomes' }[view] || view;
  tabsEl.innerHTML = state.me
    ? TABS.map((v) => `<button class="tab" data-view="${v}" role="tab" aria-selected="${v === parent}">${esc(t(`nav.${v}`))}</button>`).join('')
    : '';
  tabsEl.querySelectorAll('.tab').forEach((b) => b.addEventListener('click', () => (location.hash = `#/${b.dataset.view}`)));

  const years = [];
  const now = new Date().getFullYear();
  for (let y = now + 1; y >= now - 4; y--) years.push(String(y));
  topbar.innerHTML = `
    ${state.me ? `<label class="year-pick">${esc(t('nav.year'))}<select id="year">${options(years, (y) => y, String(state.year))}</select></label>` : ''}
    <select id="lang" aria-label="Language">${options(Object.keys(LANGS), (l) => LANGS[l], getLang())}</select>
    ${state.me ? `<button class="btn ghost small" id="logout">${esc(t('nav.logout'))}</button>` : ''}`;
  document.getElementById('year')?.addEventListener('change', (e) => {
    state.year = Number(e.target.value);
    render();
  });
  document.getElementById('lang').addEventListener('change', (e) => changeLang(e.target.value));
  document.getElementById('logout')?.addEventListener('click', () => guarded(async () => {
    await api('POST', '/api/auth/logout');
    state.me = null;
    render();
  }));
}

async function changeLang(lang) {
  setLang(lang);
  try {
    localStorage.setItem(LANG_KEY, lang);
  } catch {
    // без localStorage язык просто не запомнится в этом браузере
  }
  if (state.me) await guarded(async () => (state.me = await api('PUT', '/api/account', { lang })));
  render();
}

async function render() {
  pageRequests.abort();
  pageRequests = new AbortController();
  renderChrome();
  if (!state.me) {
    authView(location.hash === '#/register' ? 'register' : 'login');
    return;
  }
  const { view, id } = currentRoute();
  app.innerHTML = `<p class="lead">${esc(t('common.loading'))}</p>`;
  await guarded(() => VIEWS[view](id));
}

window.addEventListener('hashchange', render);

// ---------- Вход и регистрация ----------

function authView(mode) {
  const isLogin = mode === 'login';
  app.innerHTML = `
    <div class="auth card">
      <h1>${esc(t(isLogin ? 'auth.login' : 'auth.register'))}</h1>
      <p class="lead">${esc(t('auth.lead'))}</p>
      <form id="auth-form">
        <label class="field">${esc(t('auth.email'))}<input name="email" type="email" autocomplete="email" required></label>
        <label class="field">${esc(t('auth.password'))}<input name="password" type="password" minlength="${isLogin ? 1 : 8}"
          autocomplete="${isLogin ? 'current-password' : 'new-password'}" required></label>
        ${isLogin ? '' : `<p class="hint">${esc(t('auth.passwordHint'))}</p>`}
        <div class="actions"><button class="btn" type="submit">${esc(t(isLogin ? 'auth.submitLogin' : 'auth.submitRegister'))}</button></div>
      </form>
      <p class="hint"><a href="#/${isLogin ? 'register' : 'login'}">${esc(t(isLogin ? 'auth.toRegister' : 'auth.toLogin'))}</a></p>
    </div>`;
  document.getElementById('auth-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const body = { ...formData(e.target), lang: getLang() };
    guarded(async () => {
      state.me = await api('POST', isLogin ? '/api/auth/login' : '/api/auth/register', body);
      setLang(state.me.lang);
      location.hash = isLogin ? '#/overview' : '#/settings';
      render();
    });
  });
}

// ---------- Обзор ----------

async function overview() {
  const [s, profile] = await Promise.all([
    api('GET', `/api/summary?year=${state.year}`),
    api('GET', '/api/profile'),
  ]);

  const meterClass = { WARNING: 'warn', EXCEEDED: 'bad' }[s.thresholdStatus] || '';
  const percent = Math.min(Number(s.thresholdPercent || 0), 100);
  const rateText = s.ratePercent === null ? t('ov.noRate') : t('ov.rate', { rate: s.ratePercent });
  const needsSetup = !profile.name;

  app.innerHTML = `
    <h1>${needsSetup ? esc(t('ov.welcome')) : esc(profile.name)}</h1>
    <p class="lead">${esc(t(`regime.${s.regime}`))} · ${esc(t(`activity.${s.activity}`))} · ${esc(rateText)} · ${esc(t('common.year', { y: s.year }))}</p>

    ${needsSetup ? `<div class="alert"><a href="#/settings">${esc(t('ov.setup'))}</a></div>` : ''}
    ${s.warnings.map((w) => `<div class="alert ${w.code === 'THRESHOLD_EXCEEDED' || w.code === 'REGIME_NOT_ALLOWED' ? 'bad' : ''}">${esc(warningText(w))}</div>`).join('')}

    <div class="grid cols-4">
      <div class="card">
        <div class="stat-label">${esc(t('ov.income'))}</div>
        <div class="stat-value">${fmt(s.totalIncome)}</div>
        <div class="stat-sub">${esc(t('ov.incomeSub'))}</div>
      </div>
      <div class="card">
        <div class="stat-label">${esc(t('ov.tax'))}</div>
        <div class="stat-value">${fmt(s.totalTax)}</div>
        <div class="stat-sub">${esc(rateText)}</div>
      </div>
      <div class="card">
        <div class="stat-label">${esc(t('ov.due'))}</div>
        <div class="stat-value">${fmt(s.totalDue)}</div>
        <div class="stat-sub"><a href="#/report">${esc(t('ov.dueSub', { paid: fmt(s.totalPaid) }))}</a></div>
      </div>
      <div class="card">
        <div class="stat-label">${esc(t('ov.threshold'))}</div>
        <div class="stat-value">${s.threshold === null ? '—' : fmt(s.remaining)}</div>
        ${s.threshold === null ? `<div class="stat-sub">${esc(t('ov.noThreshold'))}</div>` : `
          <div class="meter">
            <div class="meter-track"><div class="meter-fill ${meterClass}" style="width:${percent}%"></div></div>
            <div class="meter-legend"><span>${esc(s.thresholdPercent)}%</span><span>${esc(t('ov.limit', { limit: fmt(s.threshold) }))}</span></div>
          </div>`}
      </div>
    </div>

    <div class="grid cols-2" style="margin-top:16px">
      <div class="card">
        <h2>${esc(t('ov.quarters'))}</h2>
        <div class="quarters">
          ${s.quarters.map((q) => `
            <a class="quarter" href="#/report/${q.quarter}">
              <div class="q">${esc(t('common.quarter', { q: q.quarter }))}</div>
              <div class="amt">${fmt(q.income)}</div>
              <div class="tax">${esc(t('ov.qTax', { tax: fmt(q.tax) }))}</div>
              ${q.due === null ? '' : `<div class="tax ${Number(q.due) > 0 ? 'owed' : 'ok'}">${Number(q.due) > 0 ? esc(t('ov.qToPay', { due: fmt(q.due) })) : esc(t('ov.qPaid'))}</div>`}
              ${q.dueDate ? `<div class="tax">${esc(t('ov.qDue', { date: fmtDate(q.dueDate) }))}</div>` : ''}
            </a>`).join('')}
        </div>
      </div>
      <div class="card">
        <h2>${esc(t('ov.deadlines'))}</h2>
        ${s.deadlines.length === 0 ? `<p class="empty">${esc(t('ov.noDeadlines'))}</p>` : `
          <ul class="deadlines">
            ${s.deadlines.map((d) => `
              <li><span class="date">${d.date ? fmtDate(d.date) : '—'}</span><span>${esc(deadlineText(d))}</span></li>`).join('')}
          </ul>`}
      </div>
    </div>

    ${Number(s.totalIncome) === 0 ? `
      <div class="card" style="margin-top:16px">
        <p>${esc(t('ov.importHint'))}</p>
        <div class="actions"><a class="btn" href="#/import">${esc(t('ov.importBtn'))}</a></div>
      </div>` : ''}`;
}

// ---------- Доходы ----------

async function incomes() {
  const list = await api('GET', `/api/incomes?year=${state.year}`);
  const total = list.reduce((sum, i) => sum + Number(i.amount), 0);

  app.innerHTML = `
    <div class="title-row">
      <h1>${esc(t('inc.title'))}</h1>
      <div class="actions">
        <a class="btn" href="#/import">${esc(t('inc.import'))}</a>
        <a class="btn ghost" href="${apiUrl('/api/export/incomes.csv')}">${esc(t('inc.export'))}</a>
      </div>
    </div>
    <p class="lead">${esc(t('inc.lead'))}</p>

    <div class="card">
      <form id="income-form">
        <div class="row">
          <label class="field">${esc(t('common.date'))}<input name="date" type="date" value="${today()}" required></label>
          <label class="field">${esc(t('inc.currency'))}<select name="currency">${options(CURRENCIES, (c) => c, 'AMD')}</select></label>
          <label class="field amd-only">${esc(t('inc.amountAmd'))}<input name="amount" type="number" min="1" step="0.01" placeholder="150000"></label>
          <label class="field fx-only" hidden>${esc(t('inc.original'))}<input name="originalAmount" type="number" min="0.01" step="0.01"></label>
          <label class="field fx-only" hidden>${esc(t('inc.rate'))}<input name="rate" type="number" min="0.0001" step="any"></label>
        </div>
        <p class="hint fx-only" id="fx-hint" hidden></p>
        <div class="row">
          <label class="field">${esc(t('common.client'))}<input name="client" maxlength="200" placeholder="${esc(t('inc.clientPh'))}"></label>
          <label class="field">${esc(t('common.description'))}<input name="description" maxlength="500" placeholder="${esc(t('inc.descPh'))}"></label>
        </div>
        <div class="actions"><button class="btn" type="submit">${esc(t('inc.add'))}</button></div>
      </form>
    </div>

    <div class="card" style="margin-top:16px">
      <h2>${esc(t('inc.yearTotal', { year: state.year, total: fmt(total) }))}</h2>
      ${list.length === 0 ? `<p class="empty">${esc(t('common.empty'))}</p>` : `
        <table>
          <thead><tr><th>${esc(t('common.date'))}</th><th>${esc(t('common.client'))}</th><th class="hide-sm">${esc(t('common.description'))}</th><th class="num">${esc(t('common.amount'))}</th><th></th></tr></thead>
          <tbody>
            ${list.map((i) => `
              <tr>
                <td>${fmtDate(i.date)}</td>
                <td>${esc(i.client)}</td>
                <td class="hide-sm">${esc(i.description)}</td>
                <td class="num">${fmt(i.amount)}${i.currency !== 'AMD' ? `<div class="stat-sub">${esc(num(i.originalAmount))} ${esc(i.currency)} × ${esc(num(i.rate, 4))}</div>` : ''}</td>
                <td class="num"><button class="btn danger small" data-delete="${i.id}">${esc(t('common.delete'))}</button></td>
              </tr>`).join('')}
          </tbody>
        </table>`}
    </div>`;

  const form = document.getElementById('income-form');
  const fxHint = document.getElementById('fx-hint');
  const syncCurrency = () => {
    const fx = form.currency.value !== 'AMD';
    form.querySelectorAll('.fx-only').forEach((el) => (el.hidden = !fx));
    form.querySelectorAll('.amd-only').forEach((el) => (el.hidden = fx));
    form.amount.required = !fx;
    form.originalAmount.required = fx;
    form.rate.required = fx;
    const amd = Math.round(Number(form.originalAmount.value || 0) * Number(form.rate.value || 0));
    fxHint.textContent = t('inc.rateHint', { amd: fmt(amd) });
  };
  form.addEventListener('input', syncCurrency);
  syncCurrency();

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const body = formData(form);
    if (body.currency === 'AMD') {
      delete body.originalAmount;
      delete body.rate;
    } else {
      delete body.amount;
    }
    guarded(async () => {
      await api('POST', '/api/incomes', body);
      toast(t('inc.added'));
      render();
    });
  });

  app.querySelectorAll('[data-delete]').forEach((b) =>
    b.addEventListener('click', () => {
      if (!confirm(t('inc.confirmDelete'))) return;
      guarded(async () => {
        await api('DELETE', `/api/incomes/${b.dataset.delete}`);
        toast(t('inc.deleted'));
        render();
      });
    }),
  );
}

// ---------- Импорт выписки ----------

/** Слова в назначении платежа, по которым строка похожа на перевод между своими счетами или возврат. */
const OWN_WORDS = ['между своими', 'свой счет', 'свой счёт', 'собственн', 'own account', 'between accounts', 'between own',
  'internal transfer', 'սեփական', 'հաշիվների միջև', 'конвертац', 'conversion', 'փոխարկում'];
const REFUND_WORDS = ['возврат', 'refund', 'chargeback', 'cashback', 'кэшбэк', 'кешбэк', 'վերադարձ'];

/** Разбирает CSV: разделитель , ; или табуляция, кавычки по RFC 4180. */
function parseCsv(text) {
  const firstLine = text.slice(0, text.indexOf('\n') >>> 0 || text.length);
  const delim = [';', '\t', ','].map((d) => [d, firstLine.split(d).length]).sort((a, b) => b[1] - a[1])[0][0];
  const rows = [];
  let row = [];
  let cell = '';
  let quoted = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (quoted) {
      if (c === '"' && text[i + 1] === '"') {
        cell += '"';
        i++;
      } else if (c === '"') {
        quoted = false;
      } else {
        cell += c;
      }
    } else if (c === '"') {
      quoted = true;
    } else if (c === delim) {
      row.push(cell);
      cell = '';
    } else if (c === '\n' || c === '\r') {
      if (c === '\r' && text[i + 1] === '\n') i++;
      row.push(cell);
      if (row.some((x) => x.trim() !== '')) rows.push(row.map((x) => x.trim()));
      row = [];
      cell = '';
    } else {
      cell += c;
    }
  }
  row.push(cell);
  if (row.some((x) => x.trim() !== '')) rows.push(row.map((x) => x.trim()));
  return rows;
}

/** Число из выписки: «1 234,56», «1,234.56», «-1234.5», «1234,5 AMD». */
function parseAmount(raw) {
  let s = String(raw || '').replace(/[\s  ']/g, '').replace(/[^\d,.\-+]/g, '');
  if (!s) return null;
  const lastComma = s.lastIndexOf(',');
  const lastDot = s.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    s = lastComma > lastDot ? s.replace(/\./g, '').replace(',', '.') : s.replace(/,/g, '');
  } else if (lastComma >= 0) {
    s = /,\d{1,2}$/.test(s) && s.split(',').length === 2 ? s.replace(',', '.') : s.replace(/,/g, '');
  }
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

const DATE_FORMATS = {
  'dd.mm.yyyy': /^(\d{1,2})[./-](\d{1,2})[./-](\d{4})/,
  'yyyy-mm-dd': /^(\d{4})[./-](\d{1,2})[./-](\d{1,2})/,
  'mm/dd/yyyy': /^(\d{1,2})[./-](\d{1,2})[./-](\d{4})/,
};

function parseDate(raw, format) {
  const m = String(raw || '').match(DATE_FORMATS[format]);
  if (!m) return null;
  const [y, mo, d] = format === 'yyyy-mm-dd' ? [m[1], m[2], m[3]] : format === 'mm/dd/yyyy' ? [m[3], m[1], m[2]] : [m[3], m[2], m[1]];
  const iso = `${y}-${mo.padStart(2, '0')}-${d.padStart(2, '0')}`;
  const check = new Date(`${iso}T00:00:00Z`);
  return Number.isNaN(check.getTime()) || check.toISOString().slice(0, 10) !== iso ? null : iso;
}

function guessDateFormat(values) {
  for (const f of ['yyyy-mm-dd', 'dd.mm.yyyy', 'mm/dd/yyyy']) {
    if (values.filter(Boolean).slice(0, 20).every((v) => parseDate(v, f))) return f;
  }
  return 'dd.mm.yyyy';
}

/** Индекс колонки, чьё название похоже на одно из слов. */
function guessColumn(header, words) {
  const i = header.findIndex((h) => words.some((w) => h.toLowerCase().includes(w)));
  return i;
}

/** Короткий отпечаток строки выписки (cyrb53), чтобы повторная загрузка не создавала дублей. */
function fingerprint(str) {
  let h1 = 0xdeadbeef;
  let h2 = 0x41c6ce57;
  for (let i = 0; i < str.length; i++) {
    const ch = str.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  return `csv-${(h2 >>> 0).toString(16)}${(h1 >>> 0).toString(16)}`;
}

function classify(amount, text) {
  if (amount === null) return 'bad';
  if (amount <= 0) return 'expense';
  const s = text.toLowerCase();
  if (OWN_WORDS.some((w) => s.includes(w))) return 'own';
  if (REFUND_WORDS.some((w) => s.includes(w))) return 'refund';
  return 'income';
}

async function importView() {
  app.innerHTML = `
    <a class="btn ghost small" href="#/incomes">← ${esc(t('inc.title'))}</a>
    <h1 style="margin-top:12px">${esc(t('imp.title'))}</h1>
    <p class="lead">${esc(t('imp.lead'))}</p>
    <div class="card">
      <label class="field">${esc(t('imp.file'))}<input type="file" id="csv-file" accept=".csv,.txt,text/csv"></label>
      <div id="mapping"></div>
    </div>
    <div id="preview"></div>`;

  document.getElementById('csv-file').addEventListener('change', async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    const buf = await file.arrayBuffer();
    let text = new TextDecoder('utf-8').decode(buf);
    // Старые выгрузки бывают в Windows-1251: в UTF-8 они превращаются в «�».
    if (text.includes('�')) text = new TextDecoder('windows-1251').decode(buf);
    const rows = parseCsv(text.replace(/^﻿/, ''));
    if (rows.length < 2) {
      toast(t('imp.empty'), true);
      return;
    }
    setupMapping(rows);
  });
}

function setupMapping(rows) {
  // Заголовок — первая строка, в которой нет даты.
  let headerIndex = 0;
  while (headerIndex < rows.length - 1 && rows[headerIndex].length < 3) headerIndex++;
  const header = rows[headerIndex];
  const data = rows.slice(headerIndex + 1);
  const cols = header.map((h, i) => [String(i), h || `#${i + 1}`]);
  const colOptions = (selected, allowNone) =>
    (allowNone ? `<option value="-1">${esc(t('imp.none'))}</option>` : '')
    + cols.map(([i, h]) => `<option value="${i}" ${Number(i) === selected ? 'selected' : ''}>${esc(h)}</option>`).join('');

  const g = {
    date: Math.max(0, guessColumn(header, ['дата', 'date', 'ամսաթիվ'])),
    amount: guessColumn(header, ['поступ', 'кредит', 'credit', 'приход', 'income', 'մուտք', 'сумма', 'amount', 'գումար']),
    debit: guessColumn(header, ['списан', 'дебет', 'debit', 'расход', 'ելք']),
    desc: guessColumn(header, ['назнач', 'описан', 'контраг', 'details', 'description', 'purpose', 'payer', 'նպատակ', 'նկարագր']),
    currency: guessColumn(header, ['валют', 'currency', 'արժույթ']),
  };
  if (g.debit === g.amount) g.debit = -1;
  const dateFormat = guessDateFormat(data.map((r) => r[g.date]));

  const mapping = document.getElementById('mapping');
  mapping.innerHTML = `
    <h2 style="margin-top:16px">${esc(t('imp.columns'))}</h2>
    <div class="row">
      <label class="field">${esc(t('imp.colDate'))}<select name="date">${colOptions(g.date, false)}</select></label>
      <label class="field">${esc(t('imp.dateFormat'))}<select name="dateFormat">${options(Object.keys(DATE_FORMATS), (f) => f, dateFormat)}</select></label>
      <label class="field">${esc(t('imp.colAmount'))}<select name="amount">${colOptions(Math.max(0, g.amount), false)}</select></label>
      <label class="field">${esc(t('imp.colDebit'))}<select name="debit">${colOptions(g.debit, true)}</select></label>
    </div>
    <div class="row">
      <label class="field">${esc(t('imp.colDesc'))}<select name="desc">${colOptions(g.desc, true)}</select></label>
      <label class="field">${esc(t('imp.colCurrency'))}<select name="currencyCol">${colOptions(g.currency, true)}</select></label>
      <label class="field">${esc(t('imp.currency'))}<select name="currency">${options(CURRENCIES, (c) => c, 'AMD')}</select></label>
      <label class="field">${esc(t('imp.defaultRate'))}<input name="rate" type="number" min="0" step="any"></label>
    </div>`;
  const read = () => Object.fromEntries([...mapping.querySelectorAll('select, input')].map((el) => [el.name, el.value]));
  mapping.addEventListener('change', () => buildPreview(data, read()));
  mapping.addEventListener('input', () => buildPreview(data, read()));
  buildPreview(data, read());
}

function buildPreview(data, m) {
  const preview = document.getElementById('preview');
  const items = data.map((r) => {
    const credit = parseAmount(r[Number(m.amount)]);
    const debit = Number(m.debit) >= 0 ? parseAmount(r[Number(m.debit)]) : null;
    // Если списание в отдельной колонке, строка с пустым поступлением — расход.
    const amount = debit && !credit ? -Math.abs(debit) : credit;
    const desc = Number(m.desc) >= 0 ? r[Number(m.desc)] || '' : '';
    const colCurrency = Number(m.currencyCol) >= 0 ? (r[Number(m.currencyCol)] || '').toUpperCase() : '';
    const currency = CURRENCIES.includes(colCurrency) ? colCurrency : m.currency;
    const date = parseDate(r[Number(m.date)], m.dateFormat);
    const status = date ? classify(amount, desc) : 'bad';
    return { date, amount, desc, currency, status, checked: status === 'income', rate: m.rate, raw: r.join('|') };
  });
  preview.innerHTML = `
    <div class="card" style="margin-top:16px">
      <p id="import-count"></p>
      <table>
        <thead><tr><th></th><th>${esc(t('common.date'))}</th><th class="num">${esc(t('common.amount'))}</th><th>${esc(t('inc.currency'))}</th><th class="num">${esc(t('inc.rate'))}</th><th>${esc(t('common.description'))}</th><th></th></tr></thead>
        <tbody>
          ${items.map((it, n) => `
            <tr class="${it.checked ? '' : 'muted'}">
              <td><input type="checkbox" data-row="${n}" ${it.checked ? 'checked' : ''} ${it.status === 'income' || it.status === 'own' || it.status === 'refund' ? '' : 'disabled'}></td>
              <td>${it.date ? fmtDate(it.date) : '—'}</td>
              <td class="num">${it.amount === null ? '—' : esc(num(it.amount))}</td>
              <td>${esc(it.currency)}</td>
              <td class="num">${it.currency === 'AMD' ? '' : `<input class="rate-input" data-rate="${n}" type="number" min="0" step="any" value="${esc(it.rate)}">`}</td>
              <td class="desc-cell">${esc(it.desc)}</td>
              <td><span class="badge ${it.status === 'income' ? 'paid' : 'sent'}">${esc(t(`imp.status.${it.status}`))}</span></td>
            </tr>`).join('')}
        </tbody>
      </table>
      <div class="actions"><button class="btn" id="import-submit">${esc(t('imp.submit'))}</button></div>
    </div>`;

  const amd = (it) => (it.currency === 'AMD' ? it.amount : it.amount * Number(it.rate || 0));
  const count = () => {
    const chosen = items.filter((it) => it.checked);
    const sum = chosen.reduce((s, it) => s + amd(it), 0);
    document.getElementById('import-count').textContent = t('imp.rows', { n: items.length, k: chosen.length, sum: fmt(Math.round(sum)) });
  };
  preview.querySelectorAll('[data-row]').forEach((cb) => cb.addEventListener('change', () => {
    items[cb.dataset.row].checked = cb.checked;
    cb.closest('tr').classList.toggle('muted', !cb.checked);
    count();
  }));
  preview.querySelectorAll('[data-rate]').forEach((input) => input.addEventListener('input', () => {
    items[input.dataset.rate].rate = input.value;
    count();
  }));
  count();

  document.getElementById('import-submit').addEventListener('click', () => {
    const chosen = items.filter((it) => it.checked);
    if (chosen.some((it) => it.currency !== 'AMD' && !(Number(it.rate) > 0))) {
      toast(t('imp.needRate'), true);
      return;
    }
    const body = {
      items: chosen.map((it) => ({
        date: it.date,
        currency: it.currency,
        ...(it.currency === 'AMD' ? { amount: String(it.amount) } : { originalAmount: String(it.amount), rate: String(it.rate) }),
        description: it.desc.slice(0, 500),
        importKey: fingerprint(it.raw),
      })),
    };
    guarded(async () => {
      const r = await api('POST', '/api/incomes/import', body);
      toast(t('imp.done', r));
      location.hash = '#/incomes';
    });
  });
}

// ---------- Отчёт и уплата ----------

async function report(period) {
  const [s, payments] = await Promise.all([
    api('GET', `/api/summary?year=${state.year}`),
    api('GET', `/api/payments?year=${state.year}`),
  ]);
  const turnover = s.regime === 'TURNOVER';
  const periods = turnover ? ['1', '2', '3', '4'] : ['0'];
  let selected = periods.includes(period) ? period : null;
  if (!selected) {
    // По умолчанию — ближайший квартал, за который ещё есть что платить.
    const owed = s.quarters.find((q) => Number(q.due) > 0);
    selected = turnover ? String(owed ? owed.quarter : Math.ceil((new Date().getMonth() + 1) / 3)) : '0';
  }
  const periodLabel = (p) => (p === '0' ? t('rep.periodYear') : t('common.quarter', { q: p }));

  let figures;
  if (selected === '0') {
    const paid = payments.filter((p) => p.quarter === 0).reduce((sum, p) => sum + Number(p.amount), 0);
    figures = { income: s.totalIncome, tax: s.totalTax, paid, due: s.totalTax === null ? null : Math.max(0, Number(s.totalTax) - paid), dueDate: null };
  } else {
    figures = s.quarters[Number(selected) - 1];
  }
  const params = {
    period: `${periodLabel(selected)} ${state.year}`,
    year: state.year,
    turnover: fmt(figures.income),
    activity: t(`activity.${s.activity}`),
    tax: fmt(figures.tax),
    toPay: fmt(figures.due),
    date: figures.dueDate ? fmtDate(figures.dueDate) : '—',
  };

  app.innerHTML = `
    <h1>${esc(t('rep.title'))}</h1>
    <p class="lead">${esc(t('rep.lead'))}</p>
    ${s.warnings.map((w) => `<div class="alert ${w.code === 'REGIME_NOT_ALLOWED' ? 'bad' : ''}">${esc(warningText(w))}</div>`).join('')}

    ${s.regime === 'GENERAL' ? `<div class="alert">${esc(t('rep.general'))}</div>` : `
    <div class="grid cols-2">
      <div class="card">
        <label class="field">${esc(t('rep.period'))}<select id="period">${options(periods, periodLabel, selected)}</select></label>
        <table class="figures">
          <tr><th>${esc(t('rep.turnover'))}</th><td class="num">${fmt(figures.income)}</td><td><button class="btn ghost small" data-copy="${esc(figures.income)}">${esc(t('common.copy'))}</button></td></tr>
          <tr><th>${esc(t('rep.rate'))}</th><td class="num">${s.ratePercent === null ? '—' : `${esc(s.ratePercent)}%`}</td><td></td></tr>
          <tr><th>${esc(t('rep.tax'))}</th><td class="num">${fmt(figures.tax)}</td><td>${figures.tax === null ? '' : `<button class="btn ghost small" data-copy="${esc(figures.tax)}">${esc(t('common.copy'))}</button>`}</td></tr>
          <tr><th>${esc(t('rep.paid'))}</th><td class="num">${fmt(figures.paid)}</td><td></td></tr>
          <tr class="strong"><th>${esc(t('rep.toPay'))}</th><td class="num">${fmt(figures.due)}</td><td></td></tr>
          ${figures.dueDate ? `<tr><th>${esc(t('rep.deadline'))}</th><td class="num">${fmtDate(figures.dueDate)}</td><td></td></tr>` : ''}
        </table>
      </div>
      <div class="card">
        <h2>${esc(t('rep.stepsTitle'))}</h2>
        <ol class="steps">
          <li>${esc(t('rep.step1'))}</li>
          <li>${esc(t(turnover ? 'rep.step2turnover' : 'rep.step2micro', params))}</li>
          ${turnover ? `<li>${esc(t('rep.step3', params))}</li><li>${esc(t('rep.step4', params))}</li><li>${esc(t('rep.step5'))}</li>` : ''}
        </ol>
        <p class="hint">${esc(t('rep.stepsNote'))}</p>
      </div>
    </div>`}

    <div class="card" style="margin-top:16px">
      <h2>${esc(t('rep.payTitle'))}</h2>
      <form id="pay-form" class="row">
        <label class="field">${esc(t('rep.period'))}<select name="quarter">${options(periods, periodLabel, selected)}</select></label>
        <label class="field">${esc(t('common.date'))}<input name="date" type="date" value="${today()}" required></label>
        <label class="field">${esc(t('common.amount'))}, ֏<input name="amount" type="number" min="1" step="1" value="${figures.due && Number(figures.due) > 0 ? esc(figures.due) : ''}" required></label>
        <div class="actions" style="align-self:end"><button class="btn" type="submit">${esc(t('rep.payAdd'))}</button></div>
      </form>
      ${payments.length === 0 ? `<p class="empty">${esc(t('rep.payEmpty'))}</p>` : `
        <table>
          <thead><tr><th>${esc(t('common.date'))}</th><th>${esc(t('rep.period'))}</th><th class="num">${esc(t('common.amount'))}</th><th></th></tr></thead>
          <tbody>
            ${payments.map((p) => `
              <tr>
                <td>${fmtDate(p.date)}</td>
                <td>${esc(periodLabel(String(p.quarter)))}</td>
                <td class="num">${fmt(p.amount)}</td>
                <td class="num"><button class="btn danger small" data-delete="${p.id}">${esc(t('common.delete'))}</button></td>
              </tr>`).join('')}
          </tbody>
        </table>`}
    </div>`;

  document.getElementById('period')?.addEventListener('change', (e) => (location.hash = `#/report/${e.target.value}`));
  app.querySelectorAll('[data-copy]').forEach((b) => b.addEventListener('click', () => copy(b.dataset.copy)));
  document.getElementById('pay-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const body = { ...formData(e.target), year: state.year };
    guarded(async () => {
      await api('POST', '/api/payments', body);
      toast(t('rep.payAdded'));
      render();
    });
  });
  app.querySelectorAll('[data-delete]').forEach((b) => b.addEventListener('click', () => {
    if (!confirm(t('rep.payConfirm'))) return;
    guarded(async () => {
      await api('DELETE', `/api/payments/${b.dataset.delete}`);
      toast(t('rep.payDeleted'));
      render();
    });
  }));
}

// ---------- Счета ----------

async function invoices() {
  const list = await api('GET', '/api/invoices');

  app.innerHTML = `
    <div class="title-row">
      <h1>${esc(t('invs.title'))}</h1>
      <a class="btn ghost" href="${apiUrl('/api/export/invoices.csv')}">${esc(t('inc.export'))}</a>
    </div>
    <p class="lead">${esc(t('invs.lead'))}</p>
    <div class="alert">${esc(t('invs.einvoiceNote'))}</div>

    <div class="card">
      <h2>${esc(t('invs.new'))}</h2>
      <form id="invoice-form">
        <div class="row">
          <label class="field">${esc(t('common.client'))}<input name="client" required maxlength="200" placeholder="${esc(t('inc.clientPh'))}"></label>
          <label class="field">${esc(t('invs.clientTin'))}<input name="clientTin" maxlength="20"></label>
          <label class="field">${esc(t('common.date'))}<input name="date" type="date" value="${today()}"></label>
          <label class="field">${esc(t('invs.due'))}<input name="dueDate" type="date"></label>
        </div>
        <table class="items-table">
          <thead><tr><th>${esc(t('invs.item'))}</th><th class="num">${esc(t('invs.qty'))}</th><th class="num">${esc(t('invs.price'))}</th><th></th></tr></thead>
          <tbody id="items"></tbody>
        </table>
        <div class="actions" style="justify-content:space-between;margin-top:8px">
          <button class="btn ghost small" type="button" id="add-item">${esc(t('invs.addItem'))}</button>
          <div class="items-total" id="items-total"></div>
        </div>
        <div class="actions"><button class="btn" type="submit">${esc(t('invs.create'))}</button></div>
      </form>
    </div>

    <div class="card" style="margin-top:16px">
      <h2>${esc(t('invs.all'))}</h2>
      ${list.length === 0 ? `<p class="empty">${esc(t('invs.none'))}</p>` : `
        <table>
          <thead><tr><th>${esc(t('invs.number'))}</th><th>${esc(t('common.date'))}</th><th>${esc(t('common.client'))}</th><th class="num">${esc(t('common.amount'))}</th><th>${esc(t('invs.status'))}</th><th class="hide-sm">e-invoice</th><th></th></tr></thead>
          <tbody>
            ${list.map((inv) => `
              <tr>
                <td><a href="#/invoice/${inv.id}">${esc(inv.number)}</a></td>
                <td>${fmtDate(inv.date)}</td>
                <td>${esc(inv.client)}</td>
                <td class="num">${fmt(inv.total)}</td>
                <td>${inv.status === 'PAID' ? `<span class="badge paid">${esc(t('invs.paid'))}</span>` : `<span class="badge sent">${esc(t('invs.waiting'))}</span>`}</td>
                <td class="hide-sm">${inv.eInvoiceNumber ? esc(inv.eInvoiceNumber) : '—'}</td>
                <td class="num">${inv.status === 'PAID' ? '' : `<button class="btn small" data-paid="${inv.id}">${esc(t('invs.markPaid'))}</button>`}</td>
              </tr>`).join('')}
          </tbody>
        </table>`}
    </div>`;

  const itemsBody = document.getElementById('items');
  const totalEl = document.getElementById('items-total');

  function recalc() {
    let total = 0;
    itemsBody.querySelectorAll('tr').forEach((tr) => {
      const q = Number(tr.querySelector('[name=quantity]').value || 0);
      const p = Number(tr.querySelector('[name=price]').value || 0);
      total += Math.round(q * p);
    });
    totalEl.textContent = `${t('common.total')}: ${fmt(total)}`;
  }

  function addItem() {
    const tr = document.createElement('tr');
    tr.innerHTML = `
      <td><input name="name" required maxlength="300" placeholder="${esc(t('invs.itemPh'))}"></td>
      <td class="num" style="width:110px"><input name="quantity" type="number" min="0.001" step="any" value="1" required></td>
      <td class="num" style="width:160px"><input name="price" type="number" min="0" step="any" required></td>
      <td class="num" style="width:44px"><button class="btn danger small" type="button" aria-label="${esc(t('invs.removeItem'))}">×</button></td>`;
    tr.querySelector('button').addEventListener('click', () => {
      if (itemsBody.children.length > 1) tr.remove();
      recalc();
    });
    tr.querySelectorAll('input').forEach((i) => i.addEventListener('input', recalc));
    itemsBody.appendChild(tr);
    recalc();
  }

  addItem();
  document.getElementById('add-item').addEventListener('click', addItem);

  document.getElementById('invoice-form').addEventListener('submit', (e) => {
    e.preventDefault();
    const form = e.target;
    const body = {
      client: form.client.value,
      clientTin: form.clientTin.value,
      date: form.date.value || null,
      dueDate: form.dueDate.value || null,
      items: [...itemsBody.querySelectorAll('tr')].map((tr) => ({
        name: tr.querySelector('[name=name]').value,
        quantity: tr.querySelector('[name=quantity]').value,
        price: tr.querySelector('[name=price]').value,
      })),
    };
    guarded(async () => {
      const inv = await api('POST', '/api/invoices', body);
      toast(t('invs.created', { number: inv.number }));
      location.hash = `#/invoice/${inv.id}`;
    });
  });

  app.querySelectorAll('[data-paid]').forEach((b) => b.addEventListener('click', () => markPaid(b.dataset.paid)));
}

function markPaid(id) {
  const date = prompt(t('invs.paidPrompt'), today());
  if (!date) return;
  guarded(async () => {
    await api('POST', `/api/invoices/${id}/paid?date=${encodeURIComponent(date)}`);
    toast(t('invs.paidDone'));
    render();
  });
}

async function invoiceView(id) {
  const [inv, profile] = await Promise.all([api('GET', `/api/invoices/${id}`), api('GET', '/api/profile')]);

  app.innerHTML = `
    <div class="actions no-print" style="justify-content:space-between;margin-bottom:16px">
      <a class="btn ghost small" href="#/invoices">${esc(t('inv.back'))}</a>
      <div class="actions">
        ${inv.status === 'PAID' ? '' : `<button class="btn ghost small" id="paid">${esc(t('inv.markPaid'))}</button>`}
        <button class="btn danger small" id="delete">${esc(t('common.delete'))}</button>
        <button class="btn small" id="print">${esc(t('inv.print'))}</button>
      </div>
    </div>

    <form id="einvoice-form" class="card no-print" style="margin-bottom:16px">
      <div class="row">
        <label class="field">${esc(t('inv.einvoice'))}<input name="eInvoiceNumber" maxlength="50" value="${esc(inv.eInvoiceNumber)}"></label>
        <div class="actions" style="align-self:end"><button class="btn ghost" type="submit">${esc(t('common.save'))}</button></div>
      </div>
      <p class="hint">${esc(t('inv.einvoiceHint'))}</p>
    </form>

    <div class="card invoice-sheet">
      <div class="head">
        <div>
          <h1>${esc(t('inv.heading', { number: inv.number }))}</h1>
          <div class="stat-sub">${esc(t('inv.from', { date: fmtDate(inv.date) }))}${inv.dueDate ? ` · ${esc(t('inv.payBy', { date: fmtDate(inv.dueDate) }))}` : ''}</div>
          ${inv.eInvoiceNumber ? `<div class="stat-sub">${esc(t('inv.einvoiceShort', { n: inv.eInvoiceNumber }))}</div>` : ''}
        </div>
        <div>${inv.status === 'PAID' ? `<span class="badge paid">${esc(t('invs.paid'))}</span>` : `<span class="badge sent">${esc(t('inv.waiting'))}</span>`}</div>
      </div>

      <div class="parties">
        <div>
          <div class="label">${esc(t('inv.seller'))}</div>
          <div><b>${profile.name ? esc(profile.name) : esc(t('inv.noName'))}</b></div>
          ${profile.tin ? `<div>${esc(t('inv.tin', { tin: profile.tin }))}</div>` : ''}
          ${profile.address ? `<div>${esc(profile.address)}</div>` : ''}
          ${profile.bankAccount ? `<div>${esc(t('inv.account', { account: profile.bankAccount }))}</div>` : ''}
        </div>
        <div>
          <div class="label">${esc(t('inv.buyer'))}</div>
          <div><b>${esc(inv.client)}</b></div>
          ${inv.clientTin ? `<div>${esc(t('inv.tin', { tin: inv.clientTin }))}</div>` : ''}
        </div>
      </div>

      <table>
        <thead><tr><th>№</th><th>${esc(t('inv.colName'))}</th><th class="num">${esc(t('invs.qty'))}</th><th class="num">${esc(t('invs.price'))}</th><th class="num">${esc(t('inv.colSum'))}</th></tr></thead>
        <tbody>
          ${inv.items.map((it, n) => `
            <tr>
              <td>${n + 1}</td>
              <td>${esc(it.name)}</td>
              <td class="num">${esc(num(it.quantity, 3))}</td>
              <td class="num">${fmt(it.price)}</td>
              <td class="num">${fmt(it.sum)}</td>
            </tr>`).join('')}
        </tbody>
      </table>
      <div class="total">${esc(t('inv.totalLine'))}: ${fmt(inv.total)}</div>

      <div class="sign"><span>${esc(t('inv.seller'))} ____________________</span><span>${esc(t('inv.buyer'))} ____________________</span></div>
    </div>`;

  document.getElementById('print').addEventListener('click', () => window.print());
  document.getElementById('paid')?.addEventListener('click', () => markPaid(inv.id));
  document.getElementById('einvoice-form').addEventListener('submit', (e) => {
    e.preventDefault();
    guarded(async () => {
      await api('PUT', `/api/invoices/${inv.id}/einvoice`, formData(e.target));
      toast(t('common.saved'));
      render();
    });
  });
  document.getElementById('delete').addEventListener('click', () => {
    if (!confirm(t('inv.confirmDelete', { number: inv.number }))) return;
    guarded(async () => {
      await api('DELETE', `/api/invoices/${inv.id}`);
      toast(t('inv.deleted'));
      location.hash = '#/invoices';
    });
  });
}

// ---------- Настройки ----------

async function settings() {
  const [p, rules] = await Promise.all([
    api('GET', '/api/profile'),
    api('GET', `/api/rules?year=${state.year}`),
  ]);
  const me = state.me;
  const byActivity = Object.fromEntries(rules.activities.map((a) => [a.activity, a]));
  const activityLabel = (k) => {
    const rate = byActivity[k]?.turnoverRate;
    return rate === null || rate === undefined ? t(`activity.${k}`) : `${t(`activity.${k}`)} (${rate}%)`;
  };
  const calendarUrl = new URL(apiUrl(me.calendarPath), location.href).href;

  app.innerHTML = `
    <h1>${esc(t('set.title'))}</h1>
    <p class="lead">${esc(t('set.lead'))}</p>

    <form id="profile-form" class="card">
      <h2>${esc(t('set.person'))}</h2>
      <div class="row">
        <label class="field">${esc(t('set.name'))}<input name="name" maxlength="200" value="${esc(p.name)}"></label>
        <label class="field">${esc(t('set.tin'))}<input name="tin" maxlength="20" value="${esc(p.tin)}"></label>
      </div>
      <div class="row">
        <label class="field">${esc(t('set.address'))}<input name="address" maxlength="300" value="${esc(p.address)}"></label>
        <label class="field">${esc(t('set.bank'))}<input name="bankAccount" maxlength="50" value="${esc(p.bankAccount)}"></label>
      </div>

      <h2 style="margin-top:18px">${esc(t('set.regimeTitle'))}</h2>
      <div class="row">
        <label class="field">${esc(t('set.regime'))}<select name="regime">${options(REGIMES, (r) => t(`regime.${r}`), p.regime)}</select></label>
        <label class="field">${esc(t('set.activity'))}<select name="activity">${options(ACTIVITIES, activityLabel, p.activity)}</select></label>
        <label class="field" id="rate-field">${esc(t('set.customRate'))}<input name="customRate" type="number" min="0" max="100" step="0.1" value="${esc(p.customRate ?? '')}"></label>
      </div>
      <div class="alert" id="regime-check" hidden></div>
      <p class="hint">${esc(t('set.hint', {
        micro: num(rules.microThreshold / 1e6), turnover: num(rules.turnoverThreshold / 1e6), year: rules.rulesFromYear,
      }))}</p>
      <div class="actions"><button class="btn" type="submit">${esc(t('common.save'))}</button></div>
    </form>

    <div class="card" style="margin-top:16px">
      <h2>${esc(t('set.reminders'))}</h2>
      <h3>${esc(t('set.calendar'))}</h3>
      <div class="inline-row">
        <input id="cal-url" readonly value="${esc(calendarUrl)}">
        <button class="btn ghost" type="button" id="cal-copy">${esc(t('common.copy'))}</button>
      </div>
      <p class="hint">${esc(t('set.calendarHint'))}</p>
      <h3 style="margin-top:14px">${esc(t('set.telegram'))}</h3>
      <div id="telegram">
        ${!me.telegramEnabled ? `<p class="hint">${esc(t('set.telegramOff'))}</p>`
          : me.telegramLinked ? `<p>${esc(t('set.telegramLinked'))}</p><button class="btn ghost small" id="tg-unlink">${esc(t('set.telegramUnlink'))}</button>`
          : `<button class="btn" id="tg-link">${esc(t('set.telegramConnect'))}</button>`}
      </div>
    </div>

    <div class="grid cols-2" style="margin-top:16px">
      <form id="account-form" class="card">
        <h2>${esc(t('set.account'))}</h2>
        <p>${esc(me.email)}</p>
        <label class="field">${esc(t('set.oldPassword'))}<input name="oldPassword" type="password" autocomplete="current-password" required></label>
        <label class="field">${esc(t('set.newPassword'))}<input name="newPassword" type="password" minlength="8" autocomplete="new-password" required></label>
        <div class="actions"><button class="btn ghost" type="submit">${esc(t('set.changePassword'))}</button></div>
      </form>
      <div class="card">
        <h2>${esc(t('set.export'))}</h2>
        <p class="hint">${esc(t('set.exportHint'))}</p>
        <div class="actions" style="flex-wrap:wrap">
          <a class="btn ghost" href="${apiUrl('/api/export/data.json')}">${esc(t('set.exportJson'))}</a>
          <a class="btn ghost" href="${apiUrl('/api/export/incomes.csv')}">${esc(t('set.exportIncomes'))}</a>
          <a class="btn ghost" href="${apiUrl('/api/export/invoices.csv')}">${esc(t('set.exportInvoices'))}</a>
        </div>
      </div>
    </div>`;

  const form = document.getElementById('profile-form');
  const rateField = document.getElementById('rate-field');
  const regimeCheck = document.getElementById('regime-check');
  const sync = () => {
    rateField.hidden = !(form.regime.value === 'TURNOVER' && form.activity.value === 'CUSTOM');
    const allowed = byActivity[form.activity.value]?.allowedRegimes ?? [];
    const ok = allowed.includes(form.regime.value);
    regimeCheck.hidden = ok;
    regimeCheck.classList.toggle('bad', !ok);
    regimeCheck.textContent = ok ? '' : t('set.notAllowed', {
      activity: t(`activity.${form.activity.value}`),
      regime: t(`regime.${form.regime.value}`),
      allowed: allowed.map((r) => t(`regime.${r}`)).join(', '),
    });
  };
  form.regime.addEventListener('change', sync);
  form.activity.addEventListener('change', sync);
  sync();

  form.addEventListener('submit', (e) => {
    e.preventDefault();
    const body = { ...formData(form), customRate: rateField.hidden ? null : form.customRate.value || null };
    guarded(async () => {
      await api('PUT', '/api/profile', body);
      toast(t('set.saved'));
      location.hash = '#/overview';
    });
  });

  document.getElementById('cal-copy').addEventListener('click', () => copy(calendarUrl));
  document.getElementById('tg-link')?.addEventListener('click', () => guarded(async () => {
    const r = await api('POST', '/api/account/telegram');
    document.getElementById('telegram').innerHTML = `
      <p>${esc(t('set.telegramOpen'))}</p>
      <p><a class="btn" href="${esc(r.link)}" target="_blank" rel="noopener">${esc(r.link)}</a></p>`;
  }));
  document.getElementById('tg-unlink')?.addEventListener('click', () => guarded(async () => {
    state.me = await api('DELETE', '/api/account/telegram');
    render();
  }));

  document.getElementById('account-form').addEventListener('submit', (e) => {
    e.preventDefault();
    guarded(async () => {
      state.me = await api('POST', '/api/account/password', formData(e.target));
      toast(t('set.passwordChanged'));
      render();
    });
  });
}

// ---------- Запуск ----------

async function start() {
  let saved = null;
  try {
    saved = localStorage.getItem(LANG_KEY);
  } catch {
    // нет доступа к localStorage
  }
  setLang(saved || browserLang());
  try {
    state.me = await api('GET', '/api/auth/me');
    setLang(state.me.lang);
  } catch {
    state.me = null;
  }
  render();
}

start();
