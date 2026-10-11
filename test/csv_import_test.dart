import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pulsar_tax/core/csv_import.dart';

const statement = '''АО Банк, выписка за октябрь
Дата;Поступление;Списание;Валюта;Назначение платежа
01.10.2026;150 000,00;;AMD;Оплата по договору 12 от ООО Пример
03.10.2026;;25 000,00;AMD;Аренда офиса
05.10.2026;500,00;;USD;"Payment for design services; Acme Inc"
06.10.2026;200 000,00;;AMD;Перевод между своими счетами
07.10.2026;3 000,00;;AMD;Возврат покупки
31.02.2026;100;;AMD;Неверная дата
''';

void main() {
  test('даты и проверка несуществующих', () {
    expect(parseDate('01.10.2026', 'dd.mm.yyyy'), '2026-10-01');
    expect(parseDate('2026-10-01 12:00', 'yyyy-mm-dd'), '2026-10-01');
    expect(parseDate('10/31/2026', 'mm/dd/yyyy'), '2026-10-31');
    expect(parseDate('31.02.2026', 'dd.mm.yyyy'), isNull);
    expect(guessDateFormat(['2026-01-05', '2026-02-10']), 'yyyy-mm-dd');
    expect(guessDateFormat(['05.01.2026']), 'dd.mm.yyyy');
  });

  test('CSV: кавычки, разделитель, пустые строки', () {
    final rows = parseCsv('a;"b;c";"d ""e"""\r\n\r\n1;2;3');
    expect(rows, [
      ['a', 'b;c', 'd "e"'],
      ['1', '2', '3'],
    ]);
    expect(parseCsv('a,b,c\n1,2,3').first, ['a', 'b', 'c']);
    expect(parseCsv('a\tb\tc').first, ['a', 'b', 'c']);
  });

  test('выписка: колонки угадываются', () {
    final st = Statement.parse(statement)!;
    expect(st.header.first, 'Дата'); // строка с названием банка пропущена
    expect(st.mapping.amount, 1);
    expect(st.mapping.debit, 2);
    expect(st.mapping.desc, 4);
    expect(st.mapping.currencyCol, 3);
    expect(st.data.length, 6);
  });

  test('отпечаток строки совпадает с веб-версией на JS', () {
    // Значения посчитаны функцией fingerprint из прежнего app.js.
    expect(fingerprint(''), 'csv-488bdcb81aee8d83');
    expect(fingerprint('01.10.2026|150 000,00||AMD|Оплата по договору 12 от ООО Пример'), 'csv-a395e1396cc54cca');
    expect(fingerprint('Ամսաթիվ|Գումար ֏'), 'csv-630c4550b61a1437');
    expect(fingerprint('x' * 1000), 'csv-819a7942aee5273b');
  });

  test('кодировка: UTF-8 с BOM и Windows-1251', () {
    expect(decodeStatement(Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('Дата')])), 'Дата');
    expect(decodeStatement(Uint8List.fromList([0xC4, 0xE0, 0xF2, 0xE0, 0x3B, 0xA8])), 'Дата;Ё');
  });

  test('слишком короткий файл', () {
    expect(Statement.parse('только заголовок'), isNull);
  });

  test('сохранённые колонки: отпечаток заголовка и применение', () {
    final a = Statement.parse(statement)!;
    final b = Statement.parse(statement.replaceFirst('Дата;Поступление', 'ДАТА;Поступление'))!;
    expect(a.signature, b.signature, reason: 'регистр в заголовке не важен');
    expect(a.signature, startsWith('csv-'));

    final saved = Map<String, dynamic>.from(a.mapping.toJson())..['desc'] = 3;
    expect(a.mapping.apply(saved, a.header.length), isTrue);
    expect(a.mapping.desc, 3);
    expect(a.mapping.apply({...saved, 'amount': 99}, a.header.length), isFalse, reason: 'колонки нет в выписке');
    expect(a.mapping.apply({...saved, 'dateFormat': 'dd-mm'}, a.header.length), isFalse);
    expect(a.mapping.amount, 1, reason: 'неподходящие настройки ничего не меняют');
  });
}
