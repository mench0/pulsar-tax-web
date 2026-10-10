// Сквозная проверка приложения против настоящего API (jar из репозитория pulsar-tax).
// Путь к jar — PULSAR_JAR, по умолчанию ../pulsar-tax/pulsar/build/pulsar-tax.jar; без него тест пропускается.
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

final jar = Platform.environment['PULSAR_JAR'] ?? '../pulsar-tax/pulsar/build/pulsar-tax.jar';

void main() {
  Process? server;
  late String base;
  late Directory dataDir;

  setUpAll(() async {
    if (!File(jar).existsSync()) return;
    HttpOverrides.global = null; // flutter_test подменяет HTTP заглушкой, здесь нужен настоящий
    dataDir = Directory.systemTemp.createTempSync('pulsar-app-test');
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    base = 'http://127.0.0.1:$port';
    server = await Process.start('java', ['-jar', jar],
        environment: {'PULSAR_PORT': '$port', 'PULSAR_DATA_DIR': dataDir.path});
    for (var i = 0; i < 100; i++) {
      try {
        if ((await http.get(Uri.parse('$base/'))).statusCode == 200) return;
      } catch (_) {
        // ещё запускается
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError('API не запустился');
  });

  tearDownAll(() {
    server?.kill();
    if (server != null) dataDir.deleteSync(recursive: true);
  });

  /// Даёт настоящим HTTP-запросам завершиться и перерисовывает экран, пока не появится [until].
  Future<void> settle(WidgetTester t, Finder until) async {
    for (var i = 0; i < 200; i++) {
      await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await t.pump(const Duration(milliseconds: 50));
      if (until.evaluate().isNotEmpty && find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
    }
    throw TestFailure('не дождались: $until');
  }

  Future<void> tap(WidgetTester t, Finder f) async {
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
      markTestSkipped('нет $jar — соберите API: ./build.sh в pulsar-tax');
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
    await t.enterText(find.byKey(const Key('email')), 'app@example.am');
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
    await t.enterText(find.byKey(const Key('email')), 'app@example.am');
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
    await t.runAsync(() => api.signIn('wide@example.am', 'пароль-широкий', register: true));
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
    expect(jsonEncode(state.me), contains('wide@example.am'));
  });
}
