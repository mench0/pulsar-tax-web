import 'package:flutter/widgets.dart';

import 'api.dart';
import 'format.dart';
import 'i18n.dart';

enum AppTab { overview, incomes, bank, report, invoices, settings }

/// Общее состояние: пользователь, язык, выбранный год и вкладка.
class AppState extends ChangeNotifier {
  AppState({required this.api, Tr? tr, this.bundle}) : tr = tr ?? Tr() {
    api.onUnauthorized = () {
      if (me == null) return;
      me = null;
      sessionExpired = true;
      notifyListeners();
    };
  }

  final Api api;
  final Tr tr;
  /// Откуда грузить переводы; null — из ресурсов приложения (в тестах подменяется).
  final AssetBundle? bundle;

  Map<String, dynamic>? me;
  bool ready = false;
  bool sessionExpired = false;
  int year = Fmt.currentYear();
  AppTab tab = AppTab.overview;

  /// Квартал, который открыть на вкладке «Отчёт» (1–4, 0 — год); null — выбрать самому.
  int? reportPeriod;

  /// Растёт при каждом изменении данных: экраны по нему перезагружаются.
  int revision = 0;

  Fmt get fmt => Fmt(tr.lang);

  Future<void> init() async {
    await tr.load(Tr.deviceLanguage(), bundle: bundle);
    try {
      me = await api.get('/api/auth/me') as Map<String, dynamic>;
      await tr.load(me!['lang'] as String, bundle: bundle);
    } catch (_) {
      me = null; // не вошли или API недоступен — покажем вход
    }
    ready = true;
    notifyListeners();
  }

  Future<void> signIn(String email, String password, {required bool register}) async {
    me = await api.signIn(email, password, register: register, lang: tr.lang);
    sessionExpired = false;
    await tr.load(me!['lang'] as String, bundle: bundle);
    tab = register ? AppTab.settings : AppTab.overview;
    notifyListeners();
  }

  Future<void> signOut() async {
    try {
      await api.signOut();
    } finally {
      me = null;
      notifyListeners();
    }
  }

  Future<void> setLang(String lang) async {
    await tr.load(lang, bundle: bundle);
    if (me != null) me = await api.put('/api/account', {'lang': lang}) as Map<String, dynamic>;
    notifyListeners();
  }

  void setMe(Map<String, dynamic> value) {
    me = value;
    notifyListeners();
  }

  void setYear(int value) {
    year = value;
    notifyListeners();
  }

  void go(AppTab value, {int? period}) {
    tab = value;
    reportPeriod = period;
    notifyListeners();
  }

  /// После изменения данных: экраны перезагрузятся.
  void changed() {
    revision++;
    notifyListeners();
  }
}

/// Доступ к AppState из любого виджета: `AppScope.of(context)`.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Без подписки на изменения — для обработчиков нажатий.
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
