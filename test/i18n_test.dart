import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulsar_tax/core/i18n.dart';

Map<String, String> load(String lang) =>
    (jsonDecode(File('assets/i18n/$lang.json').readAsStringSync()) as Map<String, dynamic>).cast();

void main() {
  test('во всех языках одинаковые ключи и непустые тексты', () {
    final ru = load('ru');
    for (final lang in ['en', 'hy']) {
      final d = load(lang);
      expect(d.keys.toSet(), ru.keys.toSet(), reason: lang);
      expect(d.values.where((v) => v.trim().isEmpty), isEmpty, reason: lang);
    }
  });

  test('ключи, которые использует код, есть в переводах', () {
    final keys = load('ru').keys.toSet();
    final used = <String>{};
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      for (final m in RegExp(r"tr\('([\w.]+)'").allMatches(f.readAsStringSync())) {
        used.add(m.group(1)!);
      }
    }
    expect(used.difference(keys), isEmpty);
    expect(used.length, greaterThan(100));
  });

  test('подстановка параметров и запасной русский', () {
    final tr = Tr.fromMaps('hy', {'a': 'բարև {name}'}, {'a': 'привет {name}', 'b': 'только по-русски'});
    expect(tr('a', {'name': 'Արամ'}), 'բարև Արամ');
    expect(tr('b'), 'только по-русски');
    expect(tr('нет'), 'нет');
    expect(tr('a'), 'բարև {name}');
  });
}
