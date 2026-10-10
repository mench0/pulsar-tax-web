import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Веб: браузер сам хранит cookie сессии (HttpOnly) и отправляет её на адрес API.
http.Client createHttpClient() => BrowserClient()..withCredentials = true;
