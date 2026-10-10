import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'http_client.dart';

/// Ошибка API с текстом для пользователя.
class ApiException implements Exception {
  ApiException(this.status, this.message);

  final int status;
  final String message;

  @override
  String toString() => message;
}

/// Где приложение хранит токен сессии. В вебе не нужен: там сессия в cookie HttpOnly.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String? token);
}

class SecureTokenStore implements TokenStore {
  static const _key = 'pulsar_session';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String? token) =>
      token == null ? _storage.delete(key: _key) : _storage.write(key: _key, value: token);
}

class MemoryTokenStore implements TokenStore {
  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String? t) async => token = t;
}

/// Клиент REST API Pulsar Tax.
///
/// Веб получает сессию в cookie, Android и iOS — токеном (tokenAuth) и шлют его в Authorization: Bearer.
class Api {
  Api({required this.base, http.Client? client, TokenStore? tokens, bool? tokenAuth})
      : _client = client ?? createHttpClient(),
        _tokens = tokens ?? (kIsWeb ? MemoryTokenStore() : SecureTokenStore()),
        tokenAuth = tokenAuth ?? !kIsWeb;

  final String base;
  final http.Client _client;
  final TokenStore _tokens;
  final bool tokenAuth;
  String? _token;
  bool _tokenLoaded = false;

  /// Вызывается, когда сервер ответил 401 на запрос после входа: сессия закончилась.
  VoidCallback? onUnauthorized;

  Uri url(String path) => Uri.parse('$base$path');

  Future<dynamic> get(String path) => _send('GET', path);

  Future<dynamic> post(String path, [Object? body]) => _send('POST', path, body);

  Future<dynamic> put(String path, Object body) => _send('PUT', path, body);

  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Вход или регистрация. Возвращает данные пользователя.
  Future<Map<String, dynamic>> signIn(String email, String password, {required bool register, String? lang}) async {
    final body = {
      'email': email,
      'password': password,
      'tokenAuth': ?(tokenAuth ? true : null),
      'lang': ?lang,
    };
    final me = await _send('POST', register ? '/api/auth/register' : '/api/auth/login', body) as Map<String, dynamic>;
    await _remember(me);
    return me;
  }

  Future<void> signOut() async {
    try {
      await _send('POST', '/api/auth/logout');
    } finally {
      await _setToken(null);
    }
  }

  /// Смена пароля выдаёт новую сессию: старый токен перестаёт работать.
  Future<Map<String, dynamic>> changePassword(String oldPassword, String newPassword) async {
    final me = await _send('POST', '/api/account/password', {'oldPassword': oldPassword, 'newPassword': newPassword})
        as Map<String, dynamic>;
    await _remember(me);
    return me;
  }

  /// Файл (CSV, JSON) с сервера.
  Future<Uint8List> bytes(String path) async {
    final res = await _client.get(url(path), headers: await _headers(false));
    _check(res, path);
    return res.bodyBytes;
  }

  Future<void> _remember(Map<String, dynamic> me) async {
    final token = me.remove('token');
    if (token is String) await _setToken(token);
  }

  Future<void> _setToken(String? token) async {
    _token = token;
    _tokenLoaded = true;
    if (tokenAuth) await _tokens.write(token);
  }

  Future<Map<String, String>> _headers(bool json) async {
    if (tokenAuth && !_tokenLoaded) {
      _token = await _tokens.read();
      _tokenLoaded = true;
    }
    return {
      if (json) 'Content-Type': 'application/json',
      if (tokenAuth && _token != null) 'Authorization': 'Bearer $_token',
    };
  }

  Future<dynamic> _send(String method, String path, [Object? body]) async {
    final req = http.Request(method, url(path))..headers.addAll(await _headers(body != null));
    if (body != null) req.body = jsonEncode(body);
    final res = await http.Response.fromStream(await _client.send(req));
    _check(res, path);
    if (res.statusCode == 204 || res.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  void _check(http.Response res, String path) {
    if (res.statusCode < 400) return;
    String message = 'Error ${res.statusCode}';
    try {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is Map && data['error'] is String) message = data['error'] as String;
    } catch (_) {
      // не JSON — оставляем код ответа
    }
    if (res.statusCode == 401 && !path.startsWith('/api/auth/')) onUnauthorized?.call();
    throw ApiException(res.statusCode, message);
  }
}
