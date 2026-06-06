import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String accessTokenStorageKey = 'stratos_access_token';
const String refreshTokenStorageKey = 'stratos_refresh_token';
const String userCacheStorageKey = 'stratos_cached_user';

String get _defaultApiBaseUrl {
  return kIsWeb ? 'http://localhost:8000/api/v1/' : 'http://10.0.2.2:8000/api/v1/';
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final apiBaseUrlProvider = Provider<String>((ref) {
  return _normalizeApiBaseUrl(_defaultApiBaseUrl);
});

final serverBaseUrlProvider = Provider<String>((ref) {
  final apiBaseUrl = ref.watch(apiBaseUrlProvider);
  final uri = Uri.parse(apiBaseUrl);
  return '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}';
});

final dioClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final baseUrl = ref.watch(apiBaseUrlProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
      headers: const <String, dynamic>{
        'Accept': 'application/json',
      },
      validateStatus: (status) => status != null && status < 400,
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: accessTokenStorageKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        } else {
          options.headers.remove('Authorization');
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

final dioProvider = dioClientProvider;

String _normalizeApiBaseUrl(String baseUrl) {
  final trimmed = baseUrl.trim();
  if (trimmed.isEmpty) {
    return kIsWeb ? 'http://localhost:8000/api/v1/' : 'http://10.0.2.2:8000/api/v1/';
  }

  final uri = Uri.parse(trimmed);
  final segments = uri.pathSegments.where((segment) => segment.isNotEmpty).toList();

  if (segments.length >= 2 &&
      segments[segments.length - 2] == 'api' &&
      segments.last == 'v1') {
    // already normalized
  } else if (segments.isNotEmpty && segments.last == 'api') {
    segments.add('v1');
  } else {
    segments.addAll(<String>['api', 'v1']);
  }

  // Force trailing slash so relative path resolution (e.g. 'auth/login')
  // doesn't eat the last path segment.
  segments.add('');

  final normalized = uri.replace(
    pathSegments: segments,
  );

  return normalized.toString().replaceAll(RegExp(r'\?$'), '');
}