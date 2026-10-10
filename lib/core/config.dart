import 'package:flutter/foundation.dart';

/// Адрес API Pulsar Tax (репозиторий pulsar-tax).
///
/// Задаётся при сборке: `flutter build web --dart-define=API_BASE=https://api.pulsar.am`.
/// Без него — адрес API при разработке: в эмуляторе Android компьютер виден как 10.0.2.2.
const String _apiBase = String.fromEnvironment('API_BASE');

String apiBase() {
  if (_apiBase.isNotEmpty) return _apiBase;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:8080';
  return 'http://127.0.0.1:8080';
}
