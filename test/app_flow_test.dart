// Сквозная проверка приложения против настоящего API (jar из репозитория pulsar-tax).
// Путь к jar — PULSAR_JAR, по умолчанию ../pulsar-tax/app/target/pulsar-tax.jar; без него тест пропускается.
// API нужен PostgreSQL: PULSAR_DB_URL, PULSAR_DB_USER, PULSAR_DB_PASSWORD (по умолчанию localhost:5432/pulsar).
@Tags(['api'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:pulsar_tax/core/api.dart';
import 'package:pulsar_tax/core/app_state.dart';
import 'package:pulsar_tax/main.dart';
import 'package:pulsar_tax/ui/common.dart';
import 'package:pulsar_tax/ui/import_screen.dart';

const statement = '''Дата;Поступление;Списание;Назначение платежа
01.10.2026;150 000,00;;Оплата по договору 12
03.10.2026;;25 000,00;Аренда офиса
06.10.2026;200 000,00;;Перевод между своими счетами
''';

/// HTTP-клиент без удержания соединений: иначе после теста остаётся таймер простоя на 15 секунд.
IOClient client() => IOClient(HttpClient()..idleTimeout = Duration.zero);

/// Свой адрес почты на каждый прогон: база API общая, прошлые прогоны в ней остаются.
final run = DateTime.now().millisecondsSinceEpoch;

final jar = Platform.environment['PULSAR_JAR'] ?? '../pulsar-tax/app/target/pulsar-tax.jar';

void main() {
  Process? server;
  late String base;
  HttpServer? cba;

  setUpAll(() async {
    if (!File(jar).existsSync()) return;
    HttpOverrides.global = null; // flutter_test подменяет HTTP заглушкой, здесь нужен настоящий
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    base = 'http://127.0.0.1:$port';
    // Заглушка API ЦБ РА: ответ в формате метода ExchangeRatesByDate.
    cba = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    cba!.listen((req) async {
      await utf8.decoder.bind(req).join();
      req.response.headers.contentType = ContentType('text', 'xml', charset: 'utf-8');
      req.response.write('<soap:Envelope><soap:Body><ExchangeRatesByDateResponse><ExchangeRatesByDateResult><Rates>'
          '<ExchangeRate><ISO>USD</ISO><Amount>1</Amount><Rate>387.5</Rate><Difference>0</Difference></ExchangeRate>'
          '<ExchangeRate><ISO>EUR</ISO><Amount>1</Amount><Rate>450</Rate><Difference>0</Difference></ExchangeRate>'
          '</Rates></ExchangeRatesByDateResult></ExchangeRatesByDateResponse></soap:Body></soap:Envelope>');
      await req.response.close();
    });
    server = await Process.start('java', ['-jar', jar], environment: {
      'PULSAR_PORT': '$port',
      'PULSAR_CBA_URL': 'http://127.0.0.1:${cba!.port}/exchangerates.asmx',
    });
    // Вывод API не нужен, но его надо вычитывать: иначе заполненный канал остановит процесс.
    server!.stdout.drain<void>();
    server!.stderr.drain<void>();
    // Spring Boot с миграциями базы запускается до полуминуты.
    for (var i = 0; i < 600; i++) {
      try {
        if ((await http.get(Uri.parse('$base/'))).statusCode == 200) return;
      } catch (_) {
        // ещё запускается
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('API не запустился: проверьте, что PostgreSQL доступен (PULSAR_DB_URL)');
  });

  tearDownAll(() {
    server?.kill();
    cba?.close(force: true);
  });

  /// Даёт настоящим HTTP-запросам завершиться и перерисовывает экран, пока не появится [until].
  Future<void> settle(WidgetTester t, Finder until) async {
    for (var i = 0; i < 200; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 50));
      if (until.evaluate().isNotEmpty && find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
    }
    final texts = t.widgetList<Text>(find.byType(Text)).map((w) => w.data).whereType<String>().join(' | ');
    throw TestFailure('не дождались: $until\nна экране: $texts');
  }

  Future<void> tap(WidgetTester t, Finder f) async {
    // Всплывающие сообщения внизу экрана перекрывают кнопки — как и у пользователя, закрываем их.
    for (final m in t.stateList<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))) {
      m.clearSnackBars();
    }
    // В середину экрана: у края элемент может оказаться под шапкой или панелью вкладок.
    // Пока идёт анимация прокрутки или смены экрана, касания игнорируются.
    await t.pump(const Duration(milliseconds: 1500));
    final element = t.element(f);
    if (Scrollable.maybeOf(element) != null) {
      await Scrollable.ensureVisible(element, alignment: .5);
    }
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(f);
    await t.pump();
  }

  Future<void> choose(WidgetTester t, Key dropdown, String item) async {
    await tap(t, find.byKey(dropdown));
    await t.pumpAndSettle();
    // Длинное меню строит только видимые пункты — прокручиваем до нужного.
    await t.scrollUntilVisible(find.text(item).last, 48, scrollable: find.byType(Scrollable).last);
    await t.tap(find.text(item).last);
    await t.pumpAndSettle();
  }

  testWidgets('путь пользователя на телефоне: вход, профиль, доходы, импорт, уплата, счёт, язык', (t) async {
    if (server == null) {
      markTestSkipped('нет $jar — соберите API: ./mvnw package в pulsar-tax');
      return;
    }
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    final tokens = MemoryTokenStore();
    final api = Api(base: base, client: client(), tokens: tokens, tokenAuth: true);
    final state = AppState(api: api);
    await t.runAsync(state.init);
    expect(state.tr.lang, 'en', reason: 'язык устройства в тестах — английский');
    await t.runAsync(() => state.setLang('ru')); // до входа язык меняется только в приложении
    await t.pumpWidget(PulsarApp(state: state));
    await settle(t, find.byKey(const Key('toggle')));

    // Регистрация → настройки.
    await tap(t, find.byKey(const Key('toggle')));
    await t.enterText(find.byKey(const Key('email')), 'app-$run@example.am');
    await t.enterText(find.byKey(const Key('password')), 'пароль-приложения');
    await tap(t, find.byKey(const Key('submit')));
    await settle(t, find.byKey(const Key('profile-name')));
    expect(tokens.token, isNotNull, reason: 'приложение получило токен, а не cookie');

    // Профиль: дизайн на микробизнесе запрещён — предупреждение; на налоге с оборота — нет.
    await t.enterText(find.byKey(const Key('profile-name')), 'ИП Арам Петросян');
    await choose(t, const Key('activity'), 'Дизайн (10%)');
    expect(find.byKey(const Key('regime-check')), findsOneWidget);
    await choose(t, const Key('regime'), 'Налог с оборота');
    expect(find.byKey(const Key('regime-check')), findsNothing);
    await tap(t, find.byKey(const Key('profile-save')));
    await settle(t, find.text('ИП Арам Петросян'));

    // Доход вручную.
    await tap(t, find.byKey(const Key('tab-incomes')));
    await settle(t, find.byKey(const Key('income-amount')));
    await t.enterText(find.byKey(const Key('income-amount')), '100000');
    await tap(t, find.byKey(const Key('income-add')));
    await settle(t, find.textContaining('100 000'));

    // Импорт выписки: поступление загружается, списание и свой перевод — нет.
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => AppScope(state: state, child: const ImportScreen(initialText: statement))));
    await settle(t, find.byKey(const Key('import-count')));
    expect(find.textContaining('Будет загружено: 1'), findsOneWidget);
    await tap(t, find.byKey(const Key('import-submit')));
    await settle(t, find.byKey(const Key('income-amount')));

    // Отчёт за 4 квартал 2026: налог 10% с оборота квартала (ручной доход — на сегодня, поэтому сверяем с API),
    // уплата закрывает долг.
    final before = await t.runAsync(() => api.get('/api/summary?year=2026')) as Map<String, dynamic>;
    final q4 = (before['quarters'] as List)[3] as Map<String, dynamic>;
    expect(q4['income'], greaterThanOrEqualTo(150000));
    expect(q4['tax'], ((q4['income'] as num) / 10).round());
    state.setYear(2026);
    state.go(AppTab.report, period: 4);
    await settle(t, find.byKey(const Key('to-pay')));
    final taxText = state.fmt.money(q4['tax']);
    expect(find.descendant(of: find.byKey(const Key('to-pay')), matching: find.text(taxText)), findsOneWidget);
    await tap(t, find.byKey(const Key('pay-add')));
    await settle(t, find.text(state.tr('rep.payAdded')));
    final after = await t.runAsync(() => api.get('/api/summary?year=2026')) as Map<String, dynamic>;
    expect((after['quarters'] as List)[3]['due'], 0);
    expect(after['totalPaid'], q4['tax']);

    // Счёт с номером e-invoice.
    await tap(t, find.byKey(const Key('tab-invoices')));
    await settle(t, find.byKey(const Key('invoice-client')));
    await t.enterText(find.byKey(const Key('invoice-client')), 'ООО Клиент');
    await t.enterText(find.byKey(const Key('item-name-0')), 'Логотип');
    await t.enterText(find.byKey(const Key('item-price-0')), '250000');
    await tap(t, find.byKey(const Key('invoice-create')));
    await settle(t, find.byKey(const Key('einvoice')));
    await t.enterText(find.byKey(const Key('einvoice')), 'E-000123');
    await tap(t, find.byKey(const Key('einvoice-save')));
    await settle(t, find.text('Сохранено'));
    final invoices = await t.runAsync(() => api.get('/api/invoices')) as List<dynamic>;
    expect(invoices.single['eInvoiceNumber'], 'E-000123');
    expect(invoices.single['total'], 250000);
    nav.pop();
    await settle(t, find.byKey(const Key('invoice-client')));

    // Армянский язык сохраняется в аккаунте.
    await t.runAsync(() => state.setLang('hy'));
    await t.pump();
    await settle(t, find.text('Ամփոփում'));
    final me = await t.runAsync(() => api.get('/api/auth/me')) as Map<String, dynamic>;
    expect(me['lang'], 'hy');

    // Выход и повторный вход тем же паролем.
    await tap(t, find.byKey(const Key('logout')));
    await settle(t, find.byKey(const Key('submit')));
    expect(tokens.token, isNull);
    await t.enterText(find.byKey(const Key('email')), 'app-$run@example.am');
    await t.enterText(find.byKey(const Key('password')), 'пароль-приложения');
    await tap(t, find.byKey(const Key('submit')));
    await settle(t, find.text('ИП Арам Петросян'));
  });

  testWidgets('широкий экран: вкладки сбоку, обзор без переполнения', (t) async {
    if (server == null) {
      markTestSkipped('нет $jar');
      return;
    }
    t.view.physicalSize = const Size(1280, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final api = Api(base: base, client: client(), tokens: MemoryTokenStore(), tokenAuth: true);
    await t.runAsync(() => api.signIn('wide-$run@example.am', 'пароль-широкий', register: true));
    final state = AppState(api: api);
    await t.runAsync(state.init);
    await t.pumpWidget(PulsarApp(state: state));
    await settle(t, find.byType(NavigationRail));
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text(state.tr('ov.welcome')), findsOneWidget);
    for (final tab in AppTab.values) {
      state.go(tab);
      await settle(t, find.byType(AppPage));
    }
    expect(jsonEncode(state.me), contains('wide-$run@example.am'));
  });

  testWidgets('бесплатные функции: курс ЦБ, копилка, расходы, запоминание колонок выписки', (t) async {
    if (server == null) {
      markTestSkipped('нет $jar');
      return;
    }
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final api = Api(base: base, client: client(), tokens: MemoryTokenStore(), tokenAuth: true);
    await t.runAsync(() => api.signIn('free-$run@example.am', 'пароль-бесплатный', register: true, lang: 'ru'));
    await t.runAsync(() => api.put('/api/profile', {'name': 'ИП Тест', 'regime': 'TURNOVER', 'activity': 'SERVICES'}));
    final state = AppState(api: api);
    await t.runAsync(state.init);
    await t.runAsync(() => state.setLang('ru'));
    state.go(AppTab.incomes);
    await t.pumpWidget(PulsarApp(state: state));
    await settle(t, find.byKey(const Key('income-amount')));

    // Курс ЦБ подставляется сам при выборе валюты.
    await choose(t, const Key('income-currency'), 'USD');
    await settle(t, find.textContaining(RegExp(r'Курс ЦБ РА на \d'))); // с датой, а не общая подсказка
    final rateField = t.widget<TextFormField>(find.byKey(const Key('income-rate')));
    expect(rateField.controller!.text, '387.5');
    await t.enterText(find.byKey(const Key('income-original')), '100');
    await tap(t, find.byKey(const Key('income-add')));
    // Копилка: 10% от 38 750 ֏.
    await settle(t, find.textContaining('Отложите 3\u00a0875 ֏ на налог'));

    // Расходы: отдельный вид, на налог не влияют.
    await tap(t, find.text('Расходы').first);
    await settle(t, find.byKey(const Key('expense-amount')));
    await t.enterText(find.byKey(const Key('expense-amount')), '5000');
    await choose(t, const Key('expense-category'), 'Программы и сервисы');
    await tap(t, find.byKey(const Key('expense-add')));
    await settle(t, find.textContaining('расходы 5\u00a0000 ֏')); // итог года, а не подпись в списке категорий
    final summary = await t.runAsync(() => api.get('/api/summary?year=${state.year}')) as Map<String, dynamic>;
    expect(summary['totalExpenses'], 5000);
    expect(summary['totalTax'], 3875);

    // Обзор: копилка и расходы.
    state.go(AppTab.overview);
    await settle(t, find.byKey(const Key('set-aside')));
    expect(find.textContaining('откладывайте 10%'), findsOneWidget);

    // Выписка в долларах: курсы ЦБ по кнопке, колонки запоминаются для следующей выписки этого банка.
    const usd = 'Date;Description;Credit;Currency\n'
        '2026-10-01;Upwork payout;200.00;USD\n'
        '2026-10-02;Client B;100.00;USD\n';
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.push(MaterialPageRoute<void>(builder: (_) => AppScope(state: state, child: const ImportScreen(initialText: usd))));
    await settle(t, find.byKey(const Key('fill-rates')));
    await tap(t, find.byKey(const Key('fill-rates')));
    await settle(t, find.textContaining('Курсы подставлены для строк: 2'));
    // Пользователь поправил колонку: назначение — вторая.
    await choose(t, const Key('map-desc'), 'Description');
    await tap(t, find.byKey(const Key('import-submit')));
    await settle(t, find.byKey(const Key('set-aside'))); // импорт открывали с «Обзора» — туда и вернулись
    final profiles = await t.runAsync(() => api.get('/api/import-profiles')) as Map<String, dynamic>;
    expect(profiles.length, 1);
    final incomes = await t.runAsync(() => api.get('/api/incomes?year=2026')) as List<dynamic>;
    expect(incomes.where((i) => i['currency'] == 'USD' && i['rate'] == 387.5).length, greaterThanOrEqualTo(2));

    nav.push(MaterialPageRoute<void>(builder: (_) => AppScope(state: state, child: const ImportScreen(initialText: usd))));
    await settle(t, find.text('Колонки подставлены из прошлой выписки этого банка'));
  });
}
