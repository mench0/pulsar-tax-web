import 'dart:convert';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';

/// Тексты интерфейса на армянском, русском и английском из assets/i18n/*.json.
/// Армянский перевод сделан без носителя языка — его нужно вычитать.
class Tr {
  static const languages = {'hy': 'Հայերեն', 'ru': 'Русский', 'en': 'English'};

  Map<String, String> _current = {};
  Map<String, String> _fallback = {};
  String lang = 'ru';

  Tr();

  /// Для тестов: словари без загрузки из assets.
  Tr.fromMaps(this.lang, Map<String, String> current, Map<String, String> fallback)
      : _current = current,
        _fallback = fallback;

  Future<void> load(String language, {AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    lang = languages.containsKey(language) ? language : 'ru';
    if (_fallback.isEmpty) _fallback = await _read(b, 'ru');
    _current = lang == 'ru' ? _fallback : await _read(b, lang);
  }

  static Future<Map<String, String>> _read(AssetBundle b, String lang) async {
    final raw = jsonDecode(await b.loadString('assets/i18n/$lang.json')) as Map<String, dynamic>;
    return raw.map((k, v) => MapEntry(k, v as String));
  }

  /// Перевод по ключу с подстановкой {параметров}. Нет перевода — русский, затем сам ключ.
  String call(String key, [Map<String, Object?> params = const {}]) {
    final text = _current[key] ?? _fallback[key] ?? key;
    return text.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
      final name = m.group(1)!;
      return params.containsKey(name) ? '${params[name]}' : m.group(0)!;
    });
  }

  /// Язык устройства, если он поддерживается.
  static String deviceLanguage() {
    final code = PlatformDispatcher.instance.locale.languageCode;
    return languages.containsKey(code) ? code : 'ru';
  }
}
