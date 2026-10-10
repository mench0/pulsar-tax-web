import 'package:intl/intl.dart';

/// Числа, суммы и даты в стиле выбранного языка.
class Fmt {
  Fmt(String lang) : _locale = const {'ru': 'ru', 'en': 'en_GB', 'hy': 'hy'}[lang] ?? 'ru';

  final String _locale;

  String number(Object? v, [int digits = 2]) {
    final n = toNum(v);
    if (n == null) return '—';
    return (NumberFormat.decimalPattern(_locale)..maximumFractionDigits = digits).format(n);
  }

  String money(Object? v) => v == null ? '—' : '${number(v)} ֏';

  static num? toNum(Object? v) => v is num ? v : v is String ? num.tryParse(v) : null;

  /// ГГГГ-ММ-ДД → ДД.ММ.ГГГГ
  static String date(String? iso) {
    if (iso == null || iso.length < 10) return '';
    return '${iso.substring(8, 10)}.${iso.substring(5, 7)}.${iso.substring(0, 4)}';
  }

  /// Сегодня по Еревану (UTC+4 круглый год) в формате ГГГГ-ММ-ДД.
  static String today([DateTime? now]) {
    final t = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 4));
    return iso(t);
  }

  static String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static int currentYear() => int.parse(today().substring(0, 4));
}
