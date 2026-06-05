import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../data/dio_client.dart';

const String _defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://stratos-fastapi-backend.onrender.com',
);

const List<String> _tokenKeys = <String>[
  'stratos_access_token',
];

Future<String?> _readStoredToken(FlutterSecureStorage storage) async {
  for (final key in _tokenKeys) {
    final value = await storage.read(key: key);
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

final apiDioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: _defaultApiBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _readStoredToken(storage);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        handler.next(response);
      },
      onError: (error, handler) {
        handler.next(error);
      },
    ),
  );

  return dio;
});

dynamic _unwrapPayload(dynamic data) {
  if (data is Map<String, dynamic>) {
    for (final key in const ['data', 'result', 'payload', 'items']) {
      final candidate = data[key];
      if (candidate != null) return candidate;
    }
  }
  return data;
}

Map<String, dynamic> asJsonMap(dynamic data) {
  final payload = _unwrapPayload(data);
  if (payload is Map<String, dynamic>) return payload;
  if (payload is Map) {
    return payload.map((key, value) => MapEntry(key.toString(), value));
  }
  throw const FormatException('Expected a JSON object from API response.');
}

List<Map<String, dynamic>> asJsonList(dynamic data) {
  final payload = _unwrapPayload(data);
  if (payload is List) {
    return payload
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
        .toList(growable: false);
  }

  if (payload is Map<String, dynamic>) {
    for (final key in const ['items', 'results', 'data', 'results']) {
      final candidate = payload[key];
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
            .toList(growable: false);
      }
    }
  }

  throw const FormatException('Expected a JSON list from API response.');
}

String encodeBody(Map<String, dynamic> body) {
  return jsonEncode(body);
}