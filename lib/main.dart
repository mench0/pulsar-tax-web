import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/api.dart';
import 'core/app_state.dart';
import 'core/config.dart';
import 'ui/auth_screen.dart';
import 'ui/common.dart';
import 'ui/shell.dart';

void main() {
  // Переводы читаются из ресурсов ещё до runApp — для этого Flutter должен быть уже запущен.
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(api: Api(base: apiBase()))..init();
  runApp(PulsarApp(state: state));
}

/// Pulsar Tax: веб, Android и iOS из одного кода.
class PulsarApp extends StatelessWidget {
  const PulsarApp({super.key, required this.state});

  final AppState state;

  /// Тема в стиле продуктов Контура: белая шапка, графитовые кнопки, светло-серый фон, белые карточки.
  static ThemeData theme(Brightness b) {
    final light = b == Brightness.light;
    final accent = light ? Brand.accent : Brand.accentDark;
    final onAccent = light ? Colors.white : Colors.black;
    final text = light ? Brand.text : Brand.textDark;
    final line = light ? Brand.line : Brand.lineDark;
    final surface = light ? Brand.surface : Brand.surfaceDark;
    final selected = light ? const Color(0xFFE6E6E6) : const Color(0xFF4D4D4D);
    final scheme = ColorScheme.fromSeed(seedColor: Brand.accent, brightness: b, dynamicSchemeVariant: DynamicSchemeVariant.monochrome)
        .copyWith(
      primary: accent,
      onPrimary: onAccent,
      secondaryContainer: selected,
      onSecondaryContainer: text,
      error: Brand.badFill,
      surface: surface,
      onSurface: text,
      outline: light ? const Color(0x29000000) : const Color(0x29FFFFFF),
      outlineVariant: line,
    );
    final rounded = RoundedRectangleBorder(borderRadius: BorderRadius.circular(8));
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'NotoSans',
      fontFamilyFallback: const ['NotoSansArmenian'],
      scaffoldBackgroundColor: light ? Brand.background : Brand.backgroundDark,
      appBarTheme: AppBarTheme(
        backgroundColor: light ? Brand.surface : Brand.headerDark,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: line)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: light ? Brand.surface : Brand.headerDark,
        indicatorColor: selected,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: light ? Brand.surface : Brand.headerDark,
        indicatorColor: selected,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: line)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: rounded)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: rounded, foregroundColor: text)),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: rounded, foregroundColor: accent)),
      dividerTheme: DividerThemeData(color: line),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Pulsar Tax',
          debugShowCheckedModeBanner: false,
          theme: theme(Brightness.light),
          darkTheme: theme(Brightness.dark),
          locale: Locale(state.tr.lang),
          supportedLocales: const [Locale('hy'), Locale('ru'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: !state.ready
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : state.me == null
                  ? const AuthScreen()
                  : const Shell(),
        ),
      ),
    );
  }
}
