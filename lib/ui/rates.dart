import '../core/app_state.dart';

/// Курсы ЦБ РА через API Pulsar (сервер сам ходит в api.cba.am и кэширует ответы).
/// Здесь — кэш на время работы приложения, чтобы импорт выписки не запрашивал одну дату дважды.
class CbaRates {
  CbaRates._();

  static final Map<String, Future<Map<String, dynamic>>> _byDate = {};

  /// Курс валюты на дату (драмов за 1 единицу) или исключение, если ЦБ недоступен.
  static Future<num> rate(AppState s, String date, String currency) async {
    final future = _byDate.putIfAbsent(date, () async {
      final r = await s.api.get('/api/rates?date=$date') as Map<String, dynamic>;
      return (r['rates'] as Map).cast<String, dynamic>();
    });
    try {
      final v = (await future)[currency];
      if (v is! num) throw StateError('нет курса $currency на $date');
      return v;
    } catch (_) {
      _byDate.remove(date); // ошибку не кэшируем: следующая попытка снова спросит сервер
      rethrow;
    }
  }
}
