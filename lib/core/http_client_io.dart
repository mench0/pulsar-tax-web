import 'package:http/http.dart' as http;

/// Android и iOS: обычный клиент, сессия — токеном в заголовке Authorization.
http.Client createHttpClient() => http.Client();
