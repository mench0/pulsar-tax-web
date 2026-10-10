// Тексты интерфейса: русский, английский, армянский.
// Армянский перевод сделан без носителя языка — перед запуском его нужно вычитать.

export const LANGS = { hy: 'Հայերեն', ru: 'Русский', en: 'English' };

const ru = {
  'app.footer': 'Расчёты оценочные и основаны на открытых данных о налогах Армении. Перед уплатой сверяйтесь с taxservice.am или бухгалтером.',
  'nav.overview': 'Обзор', 'nav.incomes': 'Доходы', 'nav.report': 'Отчёт и уплата', 'nav.invoices': 'Счета', 'nav.settings': 'Настройки',
  'nav.year': 'Год', 'nav.logout': 'Выйти',
  'common.loading': 'Загрузка…', 'common.save': 'Сохранить', 'common.delete': 'Удалить',
  'common.date': 'Дата', 'common.amount': 'Сумма', 'common.client': 'Клиент', 'common.description': 'Описание',
  'common.total': 'Итого', 'common.empty': 'Пока нет записей', 'common.saved': 'Сохранено', 'common.copied': 'Скопировано',
  'common.copy': 'Копировать', 'common.quarter': '{q} квартал', 'common.year': '{y} год',

  'auth.login': 'Вход', 'auth.register': 'Регистрация', 'auth.email': 'Почта', 'auth.password': 'Пароль',
  'auth.passwordHint': 'Не короче 8 символов', 'auth.submitLogin': 'Войти', 'auth.submitRegister': 'Создать аккаунт',
  'auth.toRegister': 'Нет аккаунта? Зарегистрируйтесь', 'auth.toLogin': 'Уже есть аккаунт? Войдите',
  'auth.lead': 'Помощник ИП в Армении: доходы, налог, сроки и счета в одном месте.',
  'auth.expired': 'Сессия закончилась, войдите снова',

  'regime.MICRO': 'Микробизнес', 'regime.TURNOVER': 'Налог с оборота', 'regime.GENERAL': 'Общая система',
  'activity.SERVICES': 'Услуги', 'activity.TRADE': 'Торговля', 'activity.HIGH_TECH': 'High-Tech, реестр',
  'activity.CONSULTING': 'Консультации', 'activity.ENGINEERING': 'Инжиниринг', 'activity.MARKETING': 'Реклама и маркетинг',
  'activity.DESIGN': 'Дизайн', 'activity.TRANSLATION': 'Перевод', 'activity.LEGAL': 'Юридические услуги',
  'activity.ACCOUNTING': 'Бухгалтерия и аудит', 'activity.AGENCY': 'Агентская деятельность', 'activity.CUSTOM': 'Своя ставка',

  'warn.REGIME_NOT_ALLOWED': 'Вид деятельности «{activity}» не может применять режим «{regime}» в {year} году. Проверьте режим с бухгалтером или в налоговой: иначе возможны доначисления и штрафы.',
  'warn.GENERAL_NOT_SUPPORTED': 'Общая система налогообложения пока не рассчитывается. Для неё нужен бухгалтер.',
  'warn.RATE_MISSING': 'Укажите ставку налога с оборота в настройках.',
  'warn.THRESHOLD_WARNING': 'Оборот приближается к порогу режима. Заранее решите, какой режим выбрать на следующий год.',
  'warn.THRESHOLD_EXCEEDED': 'Оборот превысил порог режима. Уточните у бухгалтера или в налоговой, как перейти на другой режим.',
  'deadline.TURNOVER_QUARTER': 'Расчёт и уплата налога с оборота за {quarter} квартал {year} года',
  'deadline.REGIME_CHOICE': 'Заявление о выборе налогового режима на {year} год',
  'deadline.MICRO_ANNUAL_REPORT': 'Годовой отчёт об обороте микробизнеса за {year} год. Срок уточните на taxservice.am',

  'ov.welcome': 'Добро пожаловать в Pulsar Tax', 'ov.setup': 'Начните с настроек: укажите имя, ИНН, налоговый режим и вид деятельности.',
  'ov.rate': 'ставка {rate}%', 'ov.noRate': 'не рассчитывается',
  'ov.income': 'Доход за год', 'ov.incomeSub': 'по записанным поступлениям', 'ov.tax': 'Налог за год',
  'ov.due': 'Осталось уплатить', 'ov.dueSub': 'уплачено {paid}',
  'ov.threshold': 'До порога режима', 'ov.noThreshold': 'у общей системы порога нет', 'ov.limit': 'порог {limit}',
  'ov.quarters': 'По кварталам', 'ov.qTax': 'налог {tax}', 'ov.qDue': 'до {date}', 'ov.qPaid': 'уплачено', 'ov.qToPay': 'к уплате {due}',
  'ov.deadlines': 'Ближайшие сроки', 'ov.noDeadlines': 'Сроков на этот год не осталось',
  'ov.importHint': 'Загрузите выписку банка, чтобы не вводить доходы вручную.', 'ov.importBtn': 'Загрузить выписку',

  'inc.title': 'Доходы', 'inc.lead': 'Записывайте каждое поступление денег: от них считается налог и порог режима.',
  'inc.currency': 'Валюта', 'inc.amountAmd': 'Сумма, ֏', 'inc.original': 'Сумма в валюте', 'inc.rate': 'Курс, ֏ за 1',
  'inc.rateHint': 'Курс ЦБ РА на дату поступления (cba.am). В драмах: {amd}',
  'inc.clientPh': 'ООО «Пример»', 'inc.descPh': 'Оплата за сентябрь', 'inc.add': 'Добавить доход', 'inc.added': 'Доход добавлен',
  'inc.yearTotal': '{year} год · итого {total}', 'inc.confirmDelete': 'Удалить запись о доходе?', 'inc.deleted': 'Запись удалена',
  'inc.import': 'Загрузить выписку', 'inc.export': 'Скачать CSV',

  'imp.title': 'Загрузка выписки', 'imp.lead': 'Выгрузите выписку из интернет-банка в CSV и выберите файл. Мы найдём поступления, а переводы между своими счетами и возвраты отметим отдельно. Повторная загрузка той же выписки не создаст дублей.',
  'imp.file': 'Файл CSV', 'imp.columns': 'Колонки', 'imp.colDate': 'Дата', 'imp.colAmount': 'Сумма (поступление)',
  'imp.colDebit': 'Списание (если отдельной колонкой)', 'imp.colDesc': 'Назначение / контрагент', 'imp.colCurrency': 'Валюта (колонка)',
  'imp.none': '— нет —', 'imp.dateFormat': 'Формат даты', 'imp.currency': 'Валюта выписки', 'imp.defaultRate': 'Курс по умолчанию, ֏',
  'imp.rows': 'Найдено строк: {n}. Будет загружено: {k} на сумму {sum}.',
  'imp.status.income': 'доход', 'imp.status.expense': 'списание', 'imp.status.own': 'свой перевод?', 'imp.status.refund': 'возврат?',
  'imp.status.bad': 'не распознано', 'imp.submit': 'Загрузить отмеченные', 'imp.done': 'Загружено: {added}, уже были: {skipped}',
  'imp.empty': 'В файле не нашлось строк', 'imp.needRate': 'Укажите курс для строк в валюте',

  'rep.title': 'Отчёт и уплата', 'rep.lead': 'Готовые цифры для расчёта в налоговой и учёт уплаты налога.',
  'rep.period': 'Период', 'rep.periodYear': 'Весь год', 'rep.turnover': 'Оборот за период', 'rep.rate': 'Ставка',
  'rep.tax': 'Налог', 'rep.paid': 'Уплачено', 'rep.toPay': 'К уплате', 'rep.deadline': 'Срок',
  'rep.stepsTitle': 'Как подать и оплатить',
  'rep.step1': 'Войдите в систему электронной отчётности file-online.taxservice.am с ID-картой или Mobile ID.',
  'rep.step2turnover': 'Откройте расчёт налога с оборота за {period} и укажите оборот {turnover} по виду деятельности «{activity}».',
  'rep.step2micro': 'Откройте годовой отчёт микробизнеса за {year} год и укажите оборот {turnover}.',
  'rep.step3': 'Сверьте сумму налога с расчётом системы ({tax}), подпишите и отправьте.',
  'rep.step4': 'Оплатите {toPay} до {date} через интернет-банк или приложение My Tax. Реквизиты казначейства и код платежа показываются в file-online после отправки расчёта.',
  'rep.step5': 'Отметьте уплату ниже — сумма к уплате обновится.',
  'rep.stepsNote': 'Названия разделов и граф формы могут отличаться: сверьтесь с инструкцией taxservice.am.',
  'rep.general': 'Для общей системы отчёт в Pulsar не готовится. Обратитесь к бухгалтеру.',
  'rep.payTitle': 'Уплаты налога', 'rep.payAdd': 'Отметить уплату', 'rep.payAdded': 'Уплата записана', 'rep.payDeleted': 'Уплата удалена',
  'rep.payEmpty': 'Уплат за этот год пока нет', 'rep.payConfirm': 'Удалить запись об уплате?',

  'invs.title': 'Счета', 'invs.lead': 'Счета на оплату для клиентов. Когда клиент оплатит, отметьте счёт, и доход запишется сам.',
  'invs.einvoiceNote': 'Это счёт на оплату, а не налоговый документ. Официальный электронный счёт выписывается в e-invoice.taxservice.am — сохраните его номер в карточке счёта.',
  'invs.new': 'Новый счёт', 'invs.clientTin': 'ИНН клиента', 'invs.due': 'Оплатить до', 'invs.item': 'Услуга или товар',
  'invs.qty': 'Кол-во', 'invs.price': 'Цена, ֏', 'invs.itemPh': 'Разработка сайта', 'invs.addItem': '+ Позиция',
  'invs.create': 'Создать счёт', 'invs.created': 'Счёт {number} создан', 'invs.all': 'Все счета', 'invs.none': 'Счетов пока нет',
  'invs.number': 'Номер', 'invs.status': 'Статус', 'invs.paid': 'Оплачен', 'invs.waiting': 'Ожидает', 'invs.markPaid': 'Оплачен',
  'invs.paidPrompt': 'Дата оплаты (ГГГГ-ММ-ДД)', 'invs.paidDone': 'Счёт оплачен, доход записан', 'invs.removeItem': 'Удалить позицию',

  'inv.back': '← Все счета', 'inv.markPaid': 'Отметить оплату', 'inv.print': 'Печать / PDF',
  'inv.heading': 'Счёт на оплату № {number}', 'inv.from': 'от {date}', 'inv.payBy': 'оплатить до {date}', 'inv.waiting': 'Ожидает оплаты',
  'inv.seller': 'Исполнитель', 'inv.buyer': 'Заказчик', 'inv.noName': 'Укажите имя в настройках', 'inv.tin': 'ИНН {tin}',
  'inv.account': 'Счёт {account}', 'inv.colName': 'Наименование', 'inv.colSum': 'Сумма', 'inv.totalLine': 'Итого к оплате',
  'inv.confirmDelete': 'Удалить счёт {number}? Доход по его оплате тоже удалится.', 'inv.deleted': 'Счёт удалён',
  'inv.einvoice': 'Номер электронного счёта (e-invoice)', 'inv.einvoiceHint': 'Выпишите официальный счёт в e-invoice.taxservice.am и сохраните его номер здесь.',
  'inv.einvoiceShort': 'e-invoice № {n}',

  'set.title': 'Настройки', 'set.lead': 'Эти данные попадают в счета и определяют расчёт налога.',
  'set.person': 'Предприниматель', 'set.name': 'Имя или название ИП', 'set.tin': 'ИНН', 'set.address': 'Адрес', 'set.bank': 'Банковский счёт',
  'set.regimeTitle': 'Налоговый режим', 'set.regime': 'Режим', 'set.activity': 'Вид деятельности', 'set.customRate': 'Своя ставка, %',
  'set.notAllowed': '«{activity}» не может применять режим «{regime}». Доступно: {allowed}.',
  'set.hint': 'Микробизнес — оборот до {micro} млн ֏ в год, налог с дохода не платится. Налог с оборота — до {turnover} млн ֏, ставка зависит от деятельности. Режим выбирается заявлением до 20 февраля, а при регистрации ИП — в течение 20 дней. Правила {year} года; сверьте их с бухгалтером или на taxservice.am.',
  'set.saved': 'Настройки сохранены',
  'set.account': 'Аккаунт', 'set.oldPassword': 'Текущий пароль', 'set.newPassword': 'Новый пароль',
  'set.changePassword': 'Сменить пароль', 'set.passwordChanged': 'Пароль изменён, другие устройства вышли из аккаунта',
  'set.reminders': 'Напоминания о сроках',
  'set.calendar': 'Календарь', 'set.calendarHint': 'Добавьте ссылку в Google Календарь («Добавить по URL»), Apple или Outlook: сроки появятся с напоминанием за 3 дня. Ссылка личная, не публикуйте её.',
  'set.telegram': 'Telegram', 'set.telegramOff': 'Напоминания в Telegram на этом сервере не настроены.',
  'set.telegramLinked': 'Подключён: напоминания приходят за 7, 3 и 1 день до срока.', 'set.telegramConnect': 'Подключить Telegram',
  'set.telegramOpen': 'Откройте ссылку и нажмите «Start» в Telegram. Ссылка действует 15 минут:', 'set.telegramUnlink': 'Отключить',
  'set.export': 'Экспорт данных', 'set.exportHint': 'Всё в одном файле для резервной копии или бухгалтера.',
  'set.exportJson': 'Все данные (JSON)', 'set.exportIncomes': 'Доходы (CSV)', 'set.exportInvoices': 'Счета (CSV)',
};

const en = {
  'app.footer': 'Estimates based on public information about Armenian taxes. Check with taxservice.am or an accountant before paying.',
  'nav.overview': 'Overview', 'nav.incomes': 'Income', 'nav.report': 'Return & payment', 'nav.invoices': 'Invoices', 'nav.settings': 'Settings',
  'nav.year': 'Year', 'nav.logout': 'Log out',
  'common.loading': 'Loading…', 'common.save': 'Save', 'common.delete': 'Delete',
  'common.date': 'Date', 'common.amount': 'Amount', 'common.client': 'Client', 'common.description': 'Description',
  'common.total': 'Total', 'common.empty': 'No records yet', 'common.saved': 'Saved', 'common.copied': 'Copied',
  'common.copy': 'Copy', 'common.quarter': 'Q{q}', 'common.year': '{y}',

  'auth.login': 'Log in', 'auth.register': 'Sign up', 'auth.email': 'Email', 'auth.password': 'Password',
  'auth.passwordHint': 'At least 8 characters', 'auth.submitLogin': 'Log in', 'auth.submitRegister': 'Create account',
  'auth.toRegister': 'No account? Sign up', 'auth.toLogin': 'Have an account? Log in',
  'auth.lead': 'A helper for sole proprietors in Armenia: income, tax, deadlines and invoices in one place.',
  'auth.expired': 'Your session has ended, please log in again',

  'regime.MICRO': 'Micro-business', 'regime.TURNOVER': 'Turnover tax', 'regime.GENERAL': 'General regime',
  'activity.SERVICES': 'Services', 'activity.TRADE': 'Trade', 'activity.HIGH_TECH': 'High-Tech (registered)',
  'activity.CONSULTING': 'Consulting', 'activity.ENGINEERING': 'Engineering', 'activity.MARKETING': 'Advertising & marketing',
  'activity.DESIGN': 'Design', 'activity.TRANSLATION': 'Translation', 'activity.LEGAL': 'Legal services',
  'activity.ACCOUNTING': 'Accounting & audit', 'activity.AGENCY': 'Agency activity', 'activity.CUSTOM': 'Custom rate',

  'warn.REGIME_NOT_ALLOWED': '“{activity}” cannot use the “{regime}” regime in {year}. Check your regime with an accountant or the tax office, otherwise extra tax and penalties are possible.',
  'warn.GENERAL_NOT_SUPPORTED': 'The general tax regime is not calculated yet. You need an accountant for it.',
  'warn.RATE_MISSING': 'Set your turnover tax rate in settings.',
  'warn.THRESHOLD_WARNING': 'Turnover is approaching the regime threshold. Decide in advance which regime to choose next year.',
  'warn.THRESHOLD_EXCEEDED': 'Turnover has exceeded the regime threshold. Ask an accountant or the tax office how to switch regimes.',
  'deadline.TURNOVER_QUARTER': 'Turnover tax return and payment for Q{quarter} {year}',
  'deadline.REGIME_CHOICE': 'Application to choose the tax regime for {year}',
  'deadline.MICRO_ANNUAL_REPORT': 'Annual micro-business turnover report for {year}. Check the deadline at taxservice.am',

  'ov.welcome': 'Welcome to Pulsar Tax', 'ov.setup': 'Start with settings: your name, TIN, tax regime and type of activity.',
  'ov.rate': 'rate {rate}%', 'ov.noRate': 'not calculated',
  'ov.income': 'Income this year', 'ov.incomeSub': 'from recorded receipts', 'ov.tax': 'Tax this year',
  'ov.due': 'Left to pay', 'ov.dueSub': 'paid {paid}',
  'ov.threshold': 'Left until threshold', 'ov.noThreshold': 'the general regime has no threshold', 'ov.limit': 'threshold {limit}',
  'ov.quarters': 'By quarter', 'ov.qTax': 'tax {tax}', 'ov.qDue': 'due {date}', 'ov.qPaid': 'paid', 'ov.qToPay': 'to pay {due}',
  'ov.deadlines': 'Upcoming deadlines', 'ov.noDeadlines': 'No deadlines left this year',
  'ov.importHint': 'Upload a bank statement instead of entering income by hand.', 'ov.importBtn': 'Upload statement',

  'inc.title': 'Income', 'inc.lead': 'Record every payment you receive: tax and the regime threshold are based on it.',
  'inc.currency': 'Currency', 'inc.amountAmd': 'Amount, ֏', 'inc.original': 'Amount in currency', 'inc.rate': 'Rate, ֏ per 1',
  'inc.rateHint': 'Central Bank of Armenia rate on the payment date (cba.am). In drams: {amd}',
  'inc.clientPh': 'Example LLC', 'inc.descPh': 'September payment', 'inc.add': 'Add income', 'inc.added': 'Income added',
  'inc.yearTotal': '{year} · total {total}', 'inc.confirmDelete': 'Delete this income record?', 'inc.deleted': 'Record deleted',
  'inc.import': 'Upload statement', 'inc.export': 'Download CSV',

  'imp.title': 'Upload a bank statement', 'imp.lead': 'Export a statement from online banking as CSV and choose the file. We find incoming payments and flag transfers between your own accounts and refunds. Uploading the same statement again creates no duplicates.',
  'imp.file': 'CSV file', 'imp.columns': 'Columns', 'imp.colDate': 'Date', 'imp.colAmount': 'Amount (credit)',
  'imp.colDebit': 'Debit (if a separate column)', 'imp.colDesc': 'Details / counterparty', 'imp.colCurrency': 'Currency (column)',
  'imp.none': '— none —', 'imp.dateFormat': 'Date format', 'imp.currency': 'Statement currency', 'imp.defaultRate': 'Default rate, ֏',
  'imp.rows': 'Rows found: {n}. To upload: {k} totalling {sum}.',
  'imp.status.income': 'income', 'imp.status.expense': 'debit', 'imp.status.own': 'own transfer?', 'imp.status.refund': 'refund?',
  'imp.status.bad': 'not recognised', 'imp.submit': 'Upload selected', 'imp.done': 'Uploaded: {added}, already there: {skipped}',
  'imp.empty': 'No rows found in the file', 'imp.needRate': 'Enter a rate for rows in foreign currency',

  'rep.title': 'Return & payment', 'rep.lead': 'Ready figures for your tax return and a record of tax payments.',
  'rep.period': 'Period', 'rep.periodYear': 'Whole year', 'rep.turnover': 'Turnover for the period', 'rep.rate': 'Rate',
  'rep.tax': 'Tax', 'rep.paid': 'Paid', 'rep.toPay': 'To pay', 'rep.deadline': 'Deadline',
  'rep.stepsTitle': 'How to file and pay',
  'rep.step1': 'Log in to the e-filing system file-online.taxservice.am with your ID card or Mobile ID.',
  'rep.step2turnover': 'Open the turnover tax return for {period} and enter turnover of {turnover} for “{activity}”.',
  'rep.step2micro': 'Open the annual micro-business report for {year} and enter turnover of {turnover}.',
  'rep.step3': 'Check the tax amount against the system calculation ({tax}), sign and submit.',
  'rep.step4': 'Pay {toPay} by {date} via online banking or the My Tax app. Treasury details and the payment code are shown in file-online after you submit.',
  'rep.step5': 'Record the payment below and the amount to pay will update.',
  'rep.stepsNote': 'Section and field names may differ: follow the taxservice.am instructions.',
  'rep.general': 'Pulsar does not prepare returns for the general regime. Please contact an accountant.',
  'rep.payTitle': 'Tax payments', 'rep.payAdd': 'Record payment', 'rep.payAdded': 'Payment recorded', 'rep.payDeleted': 'Payment deleted',
  'rep.payEmpty': 'No payments this year yet', 'rep.payConfirm': 'Delete this payment record?',

  'invs.title': 'Invoices', 'invs.lead': 'Payment requests for clients. When a client pays, mark the invoice and the income is recorded.',
  'invs.einvoiceNote': 'This is a payment request, not a tax document. The official electronic invoice is issued at e-invoice.taxservice.am — save its number on the invoice page.',
  'invs.new': 'New invoice', 'invs.clientTin': 'Client TIN', 'invs.due': 'Pay by', 'invs.item': 'Service or product',
  'invs.qty': 'Qty', 'invs.price': 'Price, ֏', 'invs.itemPh': 'Website development', 'invs.addItem': '+ Line',
  'invs.create': 'Create invoice', 'invs.created': 'Invoice {number} created', 'invs.all': 'All invoices', 'invs.none': 'No invoices yet',
  'invs.number': 'Number', 'invs.status': 'Status', 'invs.paid': 'Paid', 'invs.waiting': 'Waiting', 'invs.markPaid': 'Paid',
  'invs.paidPrompt': 'Payment date (YYYY-MM-DD)', 'invs.paidDone': 'Invoice paid, income recorded', 'invs.removeItem': 'Remove line',

  'inv.back': '← All invoices', 'inv.markPaid': 'Mark as paid', 'inv.print': 'Print / PDF',
  'inv.heading': 'Payment request No. {number}', 'inv.from': 'dated {date}', 'inv.payBy': 'pay by {date}', 'inv.waiting': 'Awaiting payment',
  'inv.seller': 'Supplier', 'inv.buyer': 'Customer', 'inv.noName': 'Set your name in settings', 'inv.tin': 'TIN {tin}',
  'inv.account': 'Account {account}', 'inv.colName': 'Description', 'inv.colSum': 'Amount', 'inv.totalLine': 'Total due',
  'inv.confirmDelete': 'Delete invoice {number}? Income from its payment will be deleted too.', 'inv.deleted': 'Invoice deleted',
  'inv.einvoice': 'Electronic invoice number (e-invoice)', 'inv.einvoiceHint': 'Issue the official invoice at e-invoice.taxservice.am and save its number here.',
  'inv.einvoiceShort': 'e-invoice No. {n}',

  'set.title': 'Settings', 'set.lead': 'These details appear on invoices and determine the tax calculation.',
  'set.person': 'Entrepreneur', 'set.name': 'Name or business name', 'set.tin': 'TIN', 'set.address': 'Address', 'set.bank': 'Bank account',
  'set.regimeTitle': 'Tax regime', 'set.regime': 'Regime', 'set.activity': 'Type of activity', 'set.customRate': 'Custom rate, %',
  'set.notAllowed': '“{activity}” cannot use the “{regime}” regime. Available: {allowed}.',
  'set.hint': 'Micro-business: turnover up to {micro} million ֏ a year, no tax on income. Turnover tax: up to {turnover} million ֏, the rate depends on the activity. The regime is chosen by application by 20 February, or within 20 days of registration. Rules of {year}; check them with an accountant or at taxservice.am.',
  'set.saved': 'Settings saved',
  'set.account': 'Account', 'set.oldPassword': 'Current password', 'set.newPassword': 'New password',
  'set.changePassword': 'Change password', 'set.passwordChanged': 'Password changed, other devices have been logged out',
  'set.reminders': 'Deadline reminders',
  'set.calendar': 'Calendar', 'set.calendarHint': 'Add this link to Google Calendar (“From URL”), Apple or Outlook: deadlines appear with a reminder 3 days ahead. The link is personal, do not share it.',
  'set.telegram': 'Telegram', 'set.telegramOff': 'Telegram reminders are not configured on this server.',
  'set.telegramLinked': 'Connected: reminders arrive 7, 3 and 1 day before a deadline.', 'set.telegramConnect': 'Connect Telegram',
  'set.telegramOpen': 'Open the link and press “Start” in Telegram. The link is valid for 15 minutes:', 'set.telegramUnlink': 'Disconnect',
  'set.export': 'Data export', 'set.exportHint': 'Everything in one file, for a backup or your accountant.',
  'set.exportJson': 'All data (JSON)', 'set.exportIncomes': 'Income (CSV)', 'set.exportInvoices': 'Invoices (CSV)',
};

const hy = {
  'app.footer': 'Հաշվարկները մոտավոր են և հիմնված են Հայաստանի հարկերի մասին բաց տվյալների վրա։ Վճարելուց առաջ ստուգեք taxservice.am-ում կամ հաշվապահի մոտ։',
  'nav.overview': 'Ամփոփում', 'nav.incomes': 'Եկամուտներ', 'nav.report': 'Հաշվետվություն', 'nav.invoices': 'Հաշիվներ', 'nav.settings': 'Կարգավորումներ',
  'nav.year': 'Տարի', 'nav.logout': 'Ելք',
  'common.loading': 'Բեռնվում է…', 'common.save': 'Պահպանել', 'common.delete': 'Ջնջել',
  'common.date': 'Ամսաթիվ', 'common.amount': 'Գումար', 'common.client': 'Հաճախորդ', 'common.description': 'Նկարագրություն',
  'common.total': 'Ընդամենը', 'common.empty': 'Գրառումներ դեռ չկան', 'common.saved': 'Պահպանված է', 'common.copied': 'Պատճենված է',
  'common.copy': 'Պատճենել', 'common.quarter': '{q}-րդ եռամսյակ', 'common.year': '{y} թ.',

  'auth.login': 'Մուտք', 'auth.register': 'Գրանցում', 'auth.email': 'Էլ. փոստ', 'auth.password': 'Գաղտնաբառ',
  'auth.passwordHint': 'Առնվազն 8 նիշ', 'auth.submitLogin': 'Մուտք գործել', 'auth.submitRegister': 'Ստեղծել հաշիվ',
  'auth.toRegister': 'Հաշիվ չունե՞ք։ Գրանցվեք', 'auth.toLogin': 'Արդեն ունե՞ք հաշիվ։ Մուտք գործեք',
  'auth.lead': 'Օգնական Հայաստանի անհատ ձեռնարկատերերի համար՝ եկամուտներ, հարկ, ժամկետներ և հաշիվներ մեկ տեղում։',
  'auth.expired': 'Աշխատաշրջանն ավարտվել է, մուտք գործեք նորից',

  'regime.MICRO': 'Միկրոձեռնարկատիրություն', 'regime.TURNOVER': 'Շրջանառության հարկ', 'regime.GENERAL': 'Ընդհանուր համակարգ',
  'activity.SERVICES': 'Ծառայություններ', 'activity.TRADE': 'Առևտուր', 'activity.HIGH_TECH': 'Բարձր տեխնոլոգիաներ (ռեեստր)',
  'activity.CONSULTING': 'Խորհրդատվություն', 'activity.ENGINEERING': 'Ինժեներական ծառայություններ', 'activity.MARKETING': 'Գովազդ և մարքեթինգ',
  'activity.DESIGN': 'Դիզայն', 'activity.TRANSLATION': 'Թարգմանություն', 'activity.LEGAL': 'Իրավաբանական ծառայություններ',
  'activity.ACCOUNTING': 'Հաշվապահություն և աուդիտ', 'activity.AGENCY': 'Գործակալական գործունեություն', 'activity.CUSTOM': 'Սեփական դրույքաչափ',

  'warn.REGIME_NOT_ALLOWED': '«{activity}» գործունեությունը չի կարող կիրառել «{regime}» ռեժիմը {year} թ.։ Ստուգեք ռեժիմը հաշվապահի կամ հարկային մարմնի հետ, հակառակ դեպքում հնարավոր են լրացուցիչ հարկեր և տույժեր։',
  'warn.GENERAL_NOT_SUPPORTED': 'Հարկման ընդհանուր համակարգը դեռ չի հաշվարկվում։ Դրա համար անհրաժեշտ է հաշվապահ։',
  'warn.RATE_MISSING': 'Կարգավորումներում նշեք շրջանառության հարկի դրույքաչափը։',
  'warn.THRESHOLD_WARNING': 'Շրջանառությունը մոտենում է ռեժիմի շեմին։ Նախապես որոշեք, թե որ ռեժիմն եք ընտրելու հաջորդ տարվա համար։',
  'warn.THRESHOLD_EXCEEDED': 'Շրջանառությունը գերազանցել է ռեժիմի շեմը։ Ճշտեք հաշվապահի կամ հարկային մարմնի մոտ, թե ինչպես անցնել այլ ռեժիմի։',
  'deadline.TURNOVER_QUARTER': 'Շրջանառության հարկի հաշվարկ և վճարում՝ {year} թ. {quarter}-րդ եռամսյակի համար',
  'deadline.REGIME_CHOICE': 'Դիմում {year} թ. հարկման ռեժիմի ընտրության մասին',
  'deadline.MICRO_ANNUAL_REPORT': 'Միկրոձեռնարկատիրության տարեկան հաշվետվություն {year} թ. շրջանառության մասին։ Ժամկետը ճշտեք taxservice.am-ում',

  'ov.welcome': 'Բարի գալուստ Pulsar Tax', 'ov.setup': 'Սկսեք կարգավորումներից՝ նշեք անունը, ՀՎՀՀ-ն, հարկման ռեժիմը և գործունեության տեսակը։',
  'ov.rate': 'դրույքաչափ {rate}%', 'ov.noRate': 'չի հաշվարկվում',
  'ov.income': 'Տարվա եկամուտ', 'ov.incomeSub': 'գրանցված մուտքերով', 'ov.tax': 'Տարվա հարկ',
  'ov.due': 'Մնացել է վճարել', 'ov.dueSub': 'վճարված է {paid}',
  'ov.threshold': 'Մինչև ռեժիմի շեմը', 'ov.noThreshold': 'ընդհանուր համակարգը շեմ չունի', 'ov.limit': 'շեմ {limit}',
  'ov.quarters': 'Ըստ եռամսյակների', 'ov.qTax': 'հարկ {tax}', 'ov.qDue': 'մինչև {date}', 'ov.qPaid': 'վճարված է', 'ov.qToPay': 'վճարել {due}',
  'ov.deadlines': 'Մոտակա ժամկետներ', 'ov.noDeadlines': 'Այս տարվա համար ժամկետներ չեն մնացել',
  'ov.importHint': 'Վերբեռնեք բանկային քաղվածքը, որպեսզի եկամուտները ձեռքով չմուտքագրեք։', 'ov.importBtn': 'Վերբեռնել քաղվածք',

  'inc.title': 'Եկամուտներ', 'inc.lead': 'Գրանցեք յուրաքանչյուր մուտք․ դրանցից են հաշվարկվում հարկը և ռեժիմի շեմը։',
  'inc.currency': 'Արժույթ', 'inc.amountAmd': 'Գումար, ֏', 'inc.original': 'Գումար արժույթով', 'inc.rate': 'Փոխարժեք, ֏ 1 միավորի համար',
  'inc.rateHint': 'ՀՀ ԿԲ փոխարժեքը մուտքի օրվա դրությամբ (cba.am)։ Դրամով՝ {amd}',
  'inc.clientPh': '«Օրինակ» ՍՊԸ', 'inc.descPh': 'Սեպտեմբերի վճար', 'inc.add': 'Ավելացնել եկամուտ', 'inc.added': 'Եկամուտն ավելացված է',
  'inc.yearTotal': '{year} թ. · ընդամենը {total}', 'inc.confirmDelete': 'Ջնջե՞լ եկամտի գրառումը։', 'inc.deleted': 'Գրառումը ջնջված է',
  'inc.import': 'Վերբեռնել քաղվածք', 'inc.export': 'Ներբեռնել CSV',

  'imp.title': 'Քաղվածքի վերբեռնում', 'imp.lead': 'Ինտերնետ-բանկից արտահանեք քաղվածքը CSV ձևաչափով և ընտրեք ֆայլը։ Մենք կգտնենք մուտքերը, իսկ սեփական հաշիվների միջև փոխանցումները և վերադարձները կնշենք առանձին։ Նույն քաղվածքի կրկնակի վերբեռնումը կրկնօրինակներ չի ստեղծի։',
  'imp.file': 'CSV ֆայլ', 'imp.columns': 'Սյունակներ', 'imp.colDate': 'Ամսաթիվ', 'imp.colAmount': 'Գումար (մուտք)',
  'imp.colDebit': 'Ելք (եթե առանձին սյունակ է)', 'imp.colDesc': 'Նպատակ / կոնտրագենտ', 'imp.colCurrency': 'Արժույթ (սյունակ)',
  'imp.none': '— չկա —', 'imp.dateFormat': 'Ամսաթվի ձևաչափ', 'imp.currency': 'Քաղվածքի արժույթ', 'imp.defaultRate': 'Լռելյայն փոխարժեք, ֏',
  'imp.rows': 'Գտնված տողեր՝ {n}։ Կվերբեռնվի՝ {k}, ընդամենը {sum}։',
  'imp.status.income': 'եկամուտ', 'imp.status.expense': 'ելք', 'imp.status.own': 'սեփական փոխանցո՞ւմ', 'imp.status.refund': 'վերադա՞րձ',
  'imp.status.bad': 'չճանաչված', 'imp.submit': 'Վերբեռնել նշվածները', 'imp.done': 'Վերբեռնված է՝ {added}, արդեն կային՝ {skipped}',
  'imp.empty': 'Ֆայլում տողեր չգտնվեցին', 'imp.needRate': 'Նշեք փոխարժեքը արտարժույթով տողերի համար',

  'rep.title': 'Հաշվետվություն և վճարում', 'rep.lead': 'Պատրաստի թվեր հարկային հաշվարկի համար և հարկի վճարման հաշվառում։',
  'rep.period': 'Ժամանակաշրջան', 'rep.periodYear': 'Ամբողջ տարին', 'rep.turnover': 'Շրջանառություն ժամանակաշրջանում', 'rep.rate': 'Դրույքաչափ',
  'rep.tax': 'Հարկ', 'rep.paid': 'Վճարված է', 'rep.toPay': 'Վճարման ենթակա', 'rep.deadline': 'Ժամկետ',
  'rep.stepsTitle': 'Ինչպես ներկայացնել և վճարել',
  'rep.step1': 'Մուտք գործեք file-online.taxservice.am էլեկտրոնային հաշվետվությունների համակարգ ID քարտով կամ Mobile ID-ով։',
  'rep.step2turnover': 'Բացեք շրջանառության հարկի հաշվարկը {period}-ի համար և նշեք {turnover} շրջանառություն «{activity}» գործունեության համար։',
  'rep.step2micro': 'Բացեք միկրոձեռնարկատիրության {year} թ. տարեկան հաշվետվությունը և նշեք {turnover} շրջանառություն։',
  'rep.step3': 'Համեմատեք հարկի գումարը համակարգի հաշվարկի հետ ({tax}), ստորագրեք և ուղարկեք։',
  'rep.step4': 'Վճարեք {toPay} մինչև {date} ինտերնետ-բանկի կամ My Tax հավելվածի միջոցով։ Գանձապետական վավերապայմանները և վճարման կոդը file-online-ում երևում են հաշվարկն ուղարկելուց հետո։',
  'rep.step5': 'Ներքևում նշեք վճարումը, և վճարման ենթակա գումարը կթարմացվի։',
  'rep.stepsNote': 'Բաժինների և դաշտերի անվանումները կարող են տարբերվել․ հետևեք taxservice.am-ի հրահանգին։',
  'rep.general': 'Ընդհանուր համակարգի համար Pulsar-ը հաշվետվություն չի պատրաստում։ Դիմեք հաշվապահին։',
  'rep.payTitle': 'Հարկի վճարումներ', 'rep.payAdd': 'Նշել վճարումը', 'rep.payAdded': 'Վճարումը գրանցված է', 'rep.payDeleted': 'Վճարումը ջնջված է',
  'rep.payEmpty': 'Այս տարվա վճարումներ դեռ չկան', 'rep.payConfirm': 'Ջնջե՞լ վճարման գրառումը։',

  'invs.title': 'Հաշիվներ', 'invs.lead': 'Վճարման հաշիվներ հաճախորդների համար։ Երբ հաճախորդը վճարի, նշեք հաշիվը, և եկամուտն ինքնաբերաբար կգրանցվի։',
  'invs.einvoiceNote': 'Սա վճարման հաշիվ է, ոչ թե հարկային փաստաթուղթ։ Պաշտոնական էլեկտրոնային հաշիվը դուրս է գրվում e-invoice.taxservice.am-ում․ պահպանեք դրա համարը հաշվի էջում։',
  'invs.new': 'Նոր հաշիվ', 'invs.clientTin': 'Հաճախորդի ՀՎՀՀ', 'invs.due': 'Վճարել մինչև', 'invs.item': 'Ծառայություն կամ ապրանք',
  'invs.qty': 'Քանակ', 'invs.price': 'Գին, ֏', 'invs.itemPh': 'Կայքի մշակում', 'invs.addItem': '+ Տող',
  'invs.create': 'Ստեղծել հաշիվ', 'invs.created': '{number} հաշիվը ստեղծված է', 'invs.all': 'Բոլոր հաշիվները', 'invs.none': 'Հաշիվներ դեռ չկան',
  'invs.number': 'Համար', 'invs.status': 'Կարգավիճակ', 'invs.paid': 'Վճարված', 'invs.waiting': 'Սպասվում է', 'invs.markPaid': 'Վճարված',
  'invs.paidPrompt': 'Վճարման ամսաթիվ (ՏՏՏՏ-ԱԱ-ՕՕ)', 'invs.paidDone': 'Հաշիվը վճարված է, եկամուտը գրանցված է', 'invs.removeItem': 'Ջնջել տողը',

  'inv.back': '← Բոլոր հաշիվները', 'inv.markPaid': 'Նշել վճարումը', 'inv.print': 'Տպել / PDF',
  'inv.heading': 'Վճարման հաշիվ № {number}', 'inv.from': '{date}', 'inv.payBy': 'վճարել մինչև {date}', 'inv.waiting': 'Սպասվում է վճարում',
  'inv.seller': 'Կատարող', 'inv.buyer': 'Պատվիրատու', 'inv.noName': 'Նշեք անունը կարգավորումներում', 'inv.tin': 'ՀՎՀՀ {tin}',
  'inv.account': 'Հաշիվ {account}', 'inv.colName': 'Անվանում', 'inv.colSum': 'Գումար', 'inv.totalLine': 'Ընդամենը վճարման',
  'inv.confirmDelete': 'Ջնջե՞լ {number} հաշիվը։ Դրա վճարման եկամուտը նույնպես կջնջվի։', 'inv.deleted': 'Հաշիվը ջնջված է',
  'inv.einvoice': 'Էլեկտրոնային հաշվի համար (e-invoice)', 'inv.einvoiceHint': 'Դուրս գրեք պաշտոնական հաշիվը e-invoice.taxservice.am-ում և պահպանեք դրա համարն այստեղ։',
  'inv.einvoiceShort': 'e-invoice № {n}',

  'set.title': 'Կարգավորումներ', 'set.lead': 'Այս տվյալները ներառվում են հաշիվներում և որոշում են հարկի հաշվարկը։',
  'set.person': 'Ձեռնարկատեր', 'set.name': 'Անհատ ձեռնարկատիրոջ անուն', 'set.tin': 'ՀՎՀՀ', 'set.address': 'Հասցե', 'set.bank': 'Բանկային հաշիվ',
  'set.regimeTitle': 'Հարկման ռեժիմ', 'set.regime': 'Ռեժիմ', 'set.activity': 'Գործունեության տեսակ', 'set.customRate': 'Սեփական դրույքաչափ, %',
  'set.notAllowed': '«{activity}» գործունեությունը չի կարող կիրառել «{regime}» ռեժիմը։ Հասանելի է՝ {allowed}։',
  'set.hint': 'Միկրոձեռնարկատիրություն՝ տարեկան մինչև {micro} մլն ֏ շրջանառություն, եկամտից հարկ չի վճարվում։ Շրջանառության հարկ՝ մինչև {turnover} մլն ֏, դրույքաչափը կախված է գործունեությունից։ Ռեժիմն ընտրվում է դիմումով մինչև փետրվարի 20-ը, իսկ գրանցման ժամանակ՝ 20 օրվա ընթացքում։ {year} թ. կանոններ․ ստուգեք դրանք հաշվապահի մոտ կամ taxservice.am-ում։',
  'set.saved': 'Կարգավորումները պահպանված են',
  'set.account': 'Հաշիվ', 'set.oldPassword': 'Ընթացիկ գաղտնաբառ', 'set.newPassword': 'Նոր գաղտնաբառ',
  'set.changePassword': 'Փոխել գաղտնաբառը', 'set.passwordChanged': 'Գաղտնաբառը փոխված է, մյուս սարքերից ելք է կատարվել',
  'set.reminders': 'Ժամկետների հիշեցումներ',
  'set.calendar': 'Օրացույց', 'set.calendarHint': 'Ավելացրեք այս հղումը Google Օրացույցում («URL-ով»), Apple-ում կամ Outlook-ում․ ժամկետները կհայտնվեն 3 օր առաջ հիշեցումով։ Հղումն անձնական է, մի՛ հրապարակեք։',
  'set.telegram': 'Telegram', 'set.telegramOff': 'Այս սերվերում Telegram-ի հիշեցումները կարգավորված չեն։',
  'set.telegramLinked': 'Միացված է․ հիշեցումները գալիս են ժամկետից 7, 3 և 1 օր առաջ։', 'set.telegramConnect': 'Միացնել Telegram',
  'set.telegramOpen': 'Բացեք հղումը և Telegram-ում սեղմեք «Start»։ Հղումը գործում է 15 րոպե՝', 'set.telegramUnlink': 'Անջատել',
  'set.export': 'Տվյալների արտահանում', 'set.exportHint': 'Ամբողջը մեկ ֆայլում՝ պահուստային պատճենի կամ հաշվապահի համար։',
  'set.exportJson': 'Բոլոր տվյալները (JSON)', 'set.exportIncomes': 'Եկամուտներ (CSV)', 'set.exportInvoices': 'Հաշիվներ (CSV)',
};

const DICTS = { ru, en, hy };

let current = 'ru';

export function setLang(lang) {
  current = DICTS[lang] ? lang : 'ru';
  document.documentElement.lang = current;
}

export function getLang() {
  return current;
}

/** Перевод по ключу с подстановкой {параметров}. Нет перевода — берётся русский, затем сам ключ. */
export function t(key, params = {}) {
  const text = DICTS[current][key] ?? ru[key] ?? key;
  return text.replace(/\{(\w+)\}/g, (m, name) => (name in params ? String(params[name]) : m));
}

/** Язык браузера, если он поддерживается. */
export function browserLang() {
  const l = (navigator.language || 'ru').slice(0, 2);
  return DICTS[l] ? l : 'ru';
}
