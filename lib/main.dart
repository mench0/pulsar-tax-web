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

  static ThemeData theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: Brand.amberDeep, brightness: b);
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'NotoSans',
      fontFamilyFallback: const ['NotoSansArmenian'],
      scaffoldBackgroundColor: b == Brightness.light ? const Color(0xFFF4F2EC) : const Color(0xFF0E1322),
      appBarTheme: const AppBarTheme(backgroundColor: Brand.ink, foregroundColor: Color(0xFFEEF0F6)),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: b == Brightness.light ? const Color(0xFFE3DFD5) : const Color(0xFF262E45)),
        ),
      ),
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
