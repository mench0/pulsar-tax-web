// Сквозная проверка в браузере: регистрация, профиль, доход в валюте, импорт выписки, отчёт и уплата,
// счёт с e-invoice, армянский язык, телефон, повторный вход. Нужны запущенные API и фронтенд (см. README).
const { chromium } = require('playwright');
require('fs').mkdirSync(require('path').join(__dirname, 'screenshots'), { recursive: true });
(async () => {
  const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1200, height: 900 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message)); p.on('console', m => m.type() === 'error' && errs.push(m.text()));
  p.on('dialog', d => d.accept(d.type() === 'prompt' ? '2026-10-08' : undefined));
  const toastErrors = [];
  await p.exposeFunction('reportToast', (t) => toastErrors.push(t));
  await p.addInitScript(() => new MutationObserver(() => { const el = document.querySelector('#toast.error:not([hidden])'); if (el) window.reportToast(el.textContent); }).observe(document, { subtree: true, attributes: true, childList: true }));
  const U = process.env.WEB_URL || 'http://127.0.0.1:5500/';
  const step = async (name, fn) => { try { await fn(); } catch (e) { console.log('FAIL', name, e.message.split('\n')[0]); await p.screenshot({ path: require('path').join(__dirname, `fail-${name}.png`), fullPage: true }); throw e; } };
  await step('register', async () => {
    await p.goto(U); await p.waitForSelector('#auth-form');
    await p.selectOption('#lang', 'ru'); await p.waitForTimeout(200);
    await p.click('a[href="#/register"]'); await p.waitForSelector('input[autocomplete=new-password]');
    await p.fill('input[name=email]', 'ip@example.am'); await p.fill('input[name=password]', 'парольпароль');
    await p.click('button[type=submit]'); await p.waitForSelector('#profile-form');
  });
  await step('profile', async () => {
    await p.fill('input[name=name]', 'ИП Арам Петросян'); await p.selectOption('select[name=regime]', 'TURNOVER');
    await p.selectOption('select[name=activity]', 'DESIGN'); await p.click('#profile-form button[type=submit]');
    await p.waitForFunction(() => location.hash === '#/overview' && document.querySelector('h1')?.textContent.includes('Арам'));
    await p.screenshot({ path: require('path').join(__dirname, 'screenshots', '1-overview-empty.png'), fullPage: true });
  });
  await step('fx', async () => {
    await p.goto(U + '#/incomes'); await p.waitForSelector('#income-form');
    await p.selectOption('select[name=currency]', 'EUR'); await p.fill('input[name=originalAmount]', '1000'); await p.fill('input[name=rate]', '420.5');
    console.log('fx hint:', await p.textContent('#fx-hint'));
    await p.fill('input[name=client]', 'GmbH'); await p.click('#income-form button[type=submit]');
    await p.waitForSelector('td.num .stat-sub'); console.log('fx row:', (await p.textContent('tbody tr td.num')).trim());
  });
  await step('import', async () => {
    await p.goto(U + '#/import'); await p.setInputFiles('#csv-file', require('path').join(__dirname, 'statement.csv')); await p.waitForSelector('#import-submit');
    console.log('statuses:', await p.$$eval('#preview tbody .badge', els => els.map(e => e.textContent).join(', ')));
    await p.fill('[data-rate="2"]', '387');
    console.log('count:', await p.textContent('#import-count'));
    await p.screenshot({ path: require('path').join(__dirname, 'screenshots', '2-import.png'), fullPage: true });
    await p.click('#import-submit'); await p.waitForFunction(() => location.hash === '#/incomes');
    await p.waitForSelector('tbody tr'); console.log('incomes rows:', await p.$$eval('tbody tr', r => r.length));
  });
  await step('reimport', async () => {
    await p.goto(U + '#/import'); await p.setInputFiles('#csv-file', require('path').join(__dirname, 'statement.csv')); await p.waitForSelector('#import-submit');
    await p.fill('[data-rate="2"]', '387'); await p.click('#import-submit'); await p.waitForFunction(() => document.querySelector('#toast').textContent.includes(': 0,'));
    console.log('reimport toast:', await p.textContent('#toast'));
  });
  await step('report', async () => {
    await p.goto(U + '#/report/4'); await p.waitForSelector('table.figures');
    await p.goto(U + '#/report/4'); await p.waitForSelector('table.figures');
    console.log('report:', (await p.textContent('table.figures')).replace(/\s+/g, ' ').trim());
    await p.screenshot({ path: require('path').join(__dirname, 'screenshots', '3-report.png'), fullPage: true });
    await p.click('#pay-form button[type=submit]'); await p.waitForSelector('#pay-form ~ table');
    console.log('after pay:', (await p.textContent('table.figures tr.strong')).replace(/\s+/g, ' ').trim());
  });
  await step('invoice', async () => {
    await p.goto(U + '#/invoices'); await p.waitForSelector('#invoice-form');
    await p.fill('input[name=client]', 'ООО Клиент'); await p.fill('#items input[name=name]', 'Логотип'); await p.fill('#items input[name=price]', '250000');
    await p.click('#invoice-form button[type=submit]'); await p.waitForSelector('#einvoice-form');
    await p.fill('input[name=eInvoiceNumber]', 'E-000123'); await p.click('#einvoice-form button');
    await p.waitForFunction(() => document.querySelector('.invoice-sheet .head')?.textContent.includes('E-000123'));
    console.log('invoice head:', (await p.textContent('.invoice-sheet .head')).replace(/\s+/g, ' ').trim());
  });
  await step('armenian', async () => {
    await p.selectOption('#lang', 'hy'); await p.waitForFunction(() => document.documentElement.lang === 'hy');
    await p.goto(U + '#/overview'); await p.waitForSelector('.grid.cols-4');
    await p.screenshot({ path: require('path').join(__dirname, 'screenshots', '4-overview-hy.png'), fullPage: true });
    console.log('hy tabs:', await p.$$eval('.tab', t => t.map(x => x.textContent).join(' | ')));
    console.log('hy deadline:', await p.textContent('.deadlines li'));
    await p.goto(U + '#/settings'); await p.waitForSelector('#cal-url');
    await p.screenshot({ path: require('path').join(__dirname, 'screenshots', '5-settings-hy.png'), fullPage: true });
  });
  await step('mobile', async () => {
    await p.setViewportSize({ width: 390, height: 800 }); await p.goto(U + '#/overview'); await p.waitForSelector('.grid.cols-4');
    console.log('mobile horizontal overflow:', await p.evaluate(() => document.documentElement.scrollWidth > window.innerWidth));
    await p.screenshot({ path: require('path').join(__dirname, 'screenshots', '6-mobile.png'), fullPage: true });
  });
  await step('relogin', async () => {
    await p.click('#logout'); await p.waitForSelector('#auth-form');
    await p.fill('input[name=email]', 'ip@example.am'); await p.fill('input[name=password]', 'парольпароль');
    await p.click('button[type=submit]'); await p.waitForSelector('.grid.cols-4');
    console.log('relogin lang:', await p.evaluate(() => document.documentElement.lang));
  });
  console.log('error toasts seen:', JSON.stringify(toastErrors));
  console.log('errors:', JSON.stringify(errs)); await b.close();
  // 401 на /api/auth/me до входа — ожидаемая проверка сессии.
  const real = errs.filter((e) => !e.includes('401'));
  if (real.length || toastErrors.length) process.exit(1);
  console.log('OK');
})().catch(e => { console.log('aborted'); process.exit(1); });
