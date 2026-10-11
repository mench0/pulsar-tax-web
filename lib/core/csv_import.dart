import 'dart:convert';
import 'dart:typed_data';

/// Разбор банковской выписки CSV: колонки, даты, суммы и разметка строк.
/// Не зависит от Flutter, чтобы проверяться обычными тестами.

const currencies = ['AMD', 'USD', 'EUR', 'RUB', 'GBP', 'GEL'];

/// Слова в назначении платежа, по которым строка похожа на перевод между своими счетами.
const ownWords = [
  'между своими', 'свой счет', 'свой счёт', 'собственн', 'own account', 'between accounts', 'between own',
  'internal transfer', 'սեփական', 'հաշիվների միջև', 'конвертац', 'conversion', 'փոխարկում',
];
const refundWords = ['возврат', 'refund', 'chargeback', 'cashback', 'кэшбэк', 'кешбэк', 'վերադարձ'];

enum RowStatus { income, expense, own, refund, bad }

/// Текст файла: UTF-8, а если в нём не UTF-8 — Windows-1251 (старые выгрузки банков).
String decodeStatement(Uint8List bytes) {
  try {
    return utf8.decode(bytes).replaceFirst('﻿', '');
  } on FormatException {
    return _decode1251(bytes);
  }
}

String _decode1251(Uint8List bytes) {
  const high = 'ЂЃ‚ѓ„…†‡€‰Љ‹ЊЌЋЏђ‘’“”•–—�™љ›њќћџ ЎўЈ¤Ґ¦§Ё©Є«¬­®Ї°±Ііґµ¶·ё№є»јЅѕї'
      'АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмнопрстуфхцчшщъыьэюя';
  final sb = StringBuffer();
  for (final b in bytes) {
    sb.writeCharCode(b < 0x80 ? b : high.codeUnitAt(b - 0x80));
  }
  return sb.toString();
}

/// Разделитель колонок: тот, что делит на колонки больше всего из первых десяти строк.
/// Одна первая строка не годится: у банков сверху бывает «АО Банк, выписка за октябрь».
String detectDelimiter(String text) {
  final lines = const LineSplitter().convert(text).where((l) => l.trim().isNotEmpty).take(10).toList();
  int score(String d) => lines.fold(0, (sum, l) => sum + (l.split(d).length > 2 ? 1000 : 0) + l.split(d).length - 1);
  return [';', '\t', ','].reduce((a, b) => score(b) > score(a) ? b : a);
}

/// CSV по RFC 4180; разделитель «;», табуляция или «,».
List<List<String>> parseCsv(String text) {
  final delim = detectDelimiter(text);
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;

  void endRow() {
    row.add(cell.toString());
    cell.clear();
    if (row.any((x) => x.trim().isNotEmpty)) rows.add(row.map((x) => x.trim()).toList());
    row = <String>[];
  }

  for (var i = 0; i < text.length; i++) {
    final c = text[i];
    if (quoted) {
      if (c == '"' && i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else if (c == '"') {
        quoted = false;
      } else {
        cell.write(c);
      }
    } else if (c == '"') {
      quoted = true;
    } else if (c == delim) {
      row.add(cell.toString());
      cell.clear();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else {
      cell.write(c);
    }
  }
  endRow();
  return rows;
}

/// Число из выписки: «1 234,56», «1,234.56», «-1234.5», «1234,5 AMD».
double? parseAmount(String? raw) {
  var s = (raw ?? '').replaceAll(RegExp("[\\s  ']"), '').replaceAll(RegExp(r'[^\d,.\-+]'), '');
  if (s.isEmpty) return null;
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  if (lastComma >= 0 && lastDot >= 0) {
    s = lastComma > lastDot ? s.replaceAll('.', '').replaceFirst(',', '.') : s.replaceAll(',', '');
  } else if (lastComma >= 0) {
    s = RegExp(r',\d{1,2}$').hasMatch(s) && s.split(',').length == 2 ? s.replaceFirst(',', '.') : s.replaceAll(',', '');
  }
  return double.tryParse(s);
}

const dateFormats = ['dd.mm.yyyy', 'yyyy-mm-dd', 'mm/dd/yyyy'];

/// Дата строки в формате ГГГГ-ММ-ДД или null.
String? parseDate(String? raw, String format) {
  final ymd = RegExp(r'^(\d{4})[./-](\d{1,2})[./-](\d{1,2})');
  final dmy = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})');
  final m = (format == 'yyyy-mm-dd' ? ymd : dmy).firstMatch((raw ?? '').trim());
  if (m == null) return null;
  final (y, mo, d) = switch (format) {
    'yyyy-mm-dd' => (m[1]!, m[2]!, m[3]!),
    'mm/dd/yyyy' => (m[3]!, m[1]!, m[2]!),
    _ => (m[3]!, m[2]!, m[1]!),
  };
  final year = int.parse(y), month = int.parse(mo), day = int.parse(d);
  final dt = DateTime.utc(year, month, day);
  if (dt.year != year || dt.month != month || dt.day != day) return null;
  return '$y-${mo.padLeft(2, '0')}-${d.padLeft(2, '0')}';
}

String guessDateFormat(Iterable<String?> values) {
  final sample = values.where((v) => v != null && v.isNotEmpty).take(20).toList();
  for (final f in ['yyyy-mm-dd', 'dd.mm.yyyy', 'mm/dd/yyyy']) {
    if (sample.isNotEmpty && sample.every((v) => parseDate(v, f) != null)) return f;
  }
  return 'dd.mm.yyyy';
}

/// Индекс колонки, чьё название похоже на одно из слов, или -1.
int guessColumn(List<String> header, List<String> words) =>
    header.indexWhere((h) => words.any((w) => h.toLowerCase().contains(w)));

/// Короткий отпечаток строки выписки (cyrb53), как во веб-версии: повторная загрузка не создаёт дублей.
String fingerprint(String str) {
  // Умножение по 16 бит: в вебе целые — это числа JS, и прямое a * b теряет младшие биты.
  int imul(int a, int b) {
    final ah = (a >> 16) & 0xffff, al = a & 0xffff;
    final bh = (b >> 16) & 0xffff, bl = b & 0xffff;
    return (al * bl + (((ah * bl + al * bh) << 16) & 0xffffffff)).toSigned(32);
  }
  var h1 = 0xdeadbeef.toSigned(32), h2 = 0x41c6ce57;
  for (final ch in str.codeUnits) {
    h1 = imul(h1 ^ ch, 2654435761);
    h2 = imul(h2 ^ ch, 1597334677);
  }
  h1 = imul(h1 ^ (h1.toUnsigned(32) >> 16), 2246822507) ^ imul(h2 ^ (h2.toUnsigned(32) >> 13), 3266489909);
  h2 = imul(h2 ^ (h2.toUnsigned(32) >> 16), 2246822507) ^ imul(h1 ^ (h1.toUnsigned(32) >> 13), 3266489909);
  return 'csv-${h2.toUnsigned(32).toRadixString(16)}${h1.toUnsigned(32).toRadixString(16)}';
}

RowStatus classify(double? amount, String text) {
  if (amount == null) return RowStatus.bad;
  if (amount <= 0) return RowStatus.expense;
  final s = text.toLowerCase();
  if (ownWords.any(s.contains)) return RowStatus.own;
  if (refundWords.any(s.contains)) return RowStatus.refund;
  return RowStatus.income;
}

/// Какая колонка что значит. -1 — колонки нет.
class Mapping {
  Mapping({
    required this.date,
    required this.dateFormat,
    required this.amount,
    this.debit = -1,
    this.desc = -1,
    this.currencyCol = -1,
    this.currency = 'AMD',
  });

  int date;
  String dateFormat;
  int amount;
  int debit;
  int desc;
  int currencyCol;
  String currency;

  Map<String, Object> toJson() => {
        'date': date,
        'amount': amount,
        'debit': debit,
        'desc': desc,
        'currencyCol': currencyCol,
        'dateFormat': dateFormat,
        'currency': currency,
      };

  /// Применяет сохранённое сопоставление, если оно подходит к числу колонок выписки.
  bool apply(Map<String, dynamic> saved, int columns) {
    int col(String k) => (saved[k] as num?)?.toInt() ?? -1;
    final cols = [col('date'), col('amount'), col('debit'), col('desc'), col('currencyCol')];
    if (cols[0] < 0 || cols[1] < 0 || cols.any((c) => c >= columns)) return false;
    final format = saved['dateFormat'];
    final cur = saved['currency'];
    if (!dateFormats.contains(format) || !currencies.contains(cur)) return false;
    date = cols[0];
    amount = cols[1];
    debit = cols[2];
    desc = cols[3];
    currencyCol = cols[4];
    dateFormat = format as String;
    currency = cur as String;
    return true;
  }
}

/// Выписка: заголовок, строки данных и догадка о колонках.
class Statement {
  Statement._(this.header, this.data, this.mapping);

  final List<String> header;
  final List<List<String>> data;
  final Mapping mapping;

  /// Отпечаток заголовка: по нему узнаётся выписка того же банка, чтобы подставить сохранённые колонки.
  String get signature => fingerprint(header.map((h) => h.toLowerCase()).join('|'));

  /// null, если в файле меньше двух строк.
  static Statement? parse(String text) {
    final rows = parseCsv(text);
    if (rows.length < 2) return null;
    // Заголовок — первая строка хотя бы из трёх колонок (выше бывают название банка и период).
    var h = 0;
    while (h < rows.length - 1 && rows[h].length < 3) {
      h++;
    }
    final header = rows[h];
    final data = rows.sublist(h + 1);
    final date = guessColumn(header, ['дата', 'date', 'ամսաթիվ']);
    final amount = guessColumn(header,
        ['поступ', 'кредит', 'credit', 'приход', 'income', 'մուտք', 'сумма', 'amount', 'գումար']);
    var debit = guessColumn(header, ['списан', 'дебет', 'debit', 'расход', 'ելք']);
    if (debit == amount) debit = -1;
    final dateCol = date < 0 ? 0 : date;
    return Statement._(
      header,
      data,
      Mapping(
        date: dateCol,
        dateFormat: guessDateFormat(data.map((r) => _at(r, dateCol))),
        amount: amount < 0 ? 0 : amount,
        debit: debit,
        desc: guessColumn(header,
            ['назнач', 'описан', 'контраг', 'details', 'description', 'purpose', 'payer', 'նպատակ', 'նկարագր']),
        currencyCol: guessColumn(header, ['валют', 'currency', 'արժույթ']),
      ),
    );
  }

  /// Строки выписки по текущему сопоставлению колонок.
  List<StatementRow> rows({String defaultRate = ''}) => data.map((r) {
        final m = mapping;
        final credit = parseAmount(_at(r, m.amount));
        final debit = m.debit >= 0 ? parseAmount(_at(r, m.debit)) : null;
        // Если списание в отдельной колонке, строка с пустым поступлением — расход.
        final amount = debit != null && debit != 0 && (credit == null || credit == 0) ? -debit.abs() : credit;
        final desc = m.desc >= 0 ? _at(r, m.desc) ?? '' : '';
        final colCurrency = m.currencyCol >= 0 ? (_at(r, m.currencyCol) ?? '').toUpperCase() : '';
        final currency = currencies.contains(colCurrency) ? colCurrency : m.currency;
        final date = parseDate(_at(r, m.date), m.dateFormat);
        final status = date == null ? RowStatus.bad : classify(amount, desc);
        return StatementRow(
          date: date,
          amount: amount,
          description: desc,
          currency: currency,
          status: status,
          rate: defaultRate,
          key: fingerprint(r.join('|')),
        );
      }).toList();

  static String? _at(List<String> r, int i) => i >= 0 && i < r.length ? r[i] : null;
}

class StatementRow {
  StatementRow({
    required this.date,
    required this.amount,
    required this.description,
    required this.currency,
    required this.status,
    required this.rate,
    required this.key,
  }) : checked = status == RowStatus.income;

  final String? date;
  final double? amount;
  final String description;
  final String currency;
  final RowStatus status;
  final String key;
  String rate;
  bool checked;

  /// Строку можно отметить: поступления, свои переводы и возвраты (решает пользователь).
  bool get selectable => status == RowStatus.income || status == RowStatus.own || status == RowStatus.refund;

  double get amountAmd => currency == 'AMD' ? (amount ?? 0) : (amount ?? 0) * (double.tryParse(rate) ?? 0);

  Map<String, Object?> toJson() => {
        'date': date,
        'currency': currency,
        if (currency == 'AMD') 'amount': _plain(amount!) else ...{'originalAmount': _plain(amount!), 'rate': rate},
        'description': description.length > 500 ? description.substring(0, 500) : description,
        'importKey': key,
      };

  static String _plain(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
