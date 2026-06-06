import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../data/dio_client.dart';
import '../../../data/json_parsing.dart';

import '../domain/auth_session_model.dart';
import '../domain/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(dioClientProvider),
    storage: ref.watch(secureStorageProvider),
  );
});

class AuthRepository {
  final Dio dio;
  final FlutterSecureStorage storage;
  static String? _cachedUserId;

  const AuthRepository({required this.dio, required this.storage});

  Future<AuthSessionModel> login({
    required String email,
    required String password,
  }) {
    return signIn(email: email, password: password);
  }

  Future<AuthSessionModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await dio.post<dynamic>(
        'auth/login',
        data: <String, dynamic>{'email': email.trim(), 'password': password},
      );
      final session = AuthSessionModel.fromJson(response.data);
      _cachedUserId = session.user?.id;
      await _persistSession(session);
      return session;
    } on DioException catch (e) {
      throw Exception(_extractApiErrorMessage(e.response?.data, fallbackMessage: 'Login failed'));
    }
  }

  Future<UserModel> register({
    required String email,
    required String password,
    String? fullName,
    EduLevel? eduLevel,
    UserRole? role,
  }) {
    return signUp(
      email: email,
      password: password,
      fullName: fullName,
      eduLevel: eduLevel,
      role: role,
    );
  }

  Future<UserModel> signUp({
    required String email,
    required String password,
    String? fullName,
    EduLevel? eduLevel,
    UserRole? role,
  }) async {
    try {
      final response = await dio.post<dynamic>(
        'auth/register',
        data: <String, dynamic>{
          'email': email.trim(),
          'password': password,
          if (fullName != null && fullName.trim().isNotEmpty)
            'full_name': fullName.trim(),
          if (eduLevel != null && eduLevel != EduLevel.unknown)
            'edu_level': eduLevel.toJson(),
          if (role != null && role != UserRole.unknown) 'role': role.toJson(),
          'is_active': true,
        },
      );
      final user = UserModel.fromJson(response.data);
      return user;
    } on DioException catch (e) {
      throw Exception(_extractApiErrorMessage(e.response?.data, fallbackMessage: 'Registration failed'));
    }
  }

  Future<UserModel> fetchMe() async {
    try {
      final response = await dio.get<dynamic>('users/me');
      final user = UserModel.fromJson(response.data);
      _cachedUserId = user.id;
      await _persistCachedUser(user);
      return user;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await logout();
        throw Exception('Session expired');
      }
      throw Exception(_extractApiErrorMessage(e.response?.data, fallbackMessage: 'Failed to load user profile'));
    }
  }

  Future<UserModel> currentUser() => fetchMe();

  Future<List<UserModel>> fetchContacts({String? query}) async {
    try {
      final response = await dio.get<dynamic>(
        'users/contacts',
        queryParameters: {
          if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        },
      );
      return asJsonMapList(response.data).map(UserModel.fromJson).toList();
    } on DioException catch (e) {
      throw Exception(_extractApiErrorMessage(e.response?.data, fallbackMessage: 'Failed to load contacts'));
    }
  }

  Future<UserModel> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      final response = await dio.patch<dynamic>('users/$userId', data: data);
      try {
        final user = UserModel.fromJson(response.data);
        _cachedUserId = user.id;
        await _persistCachedUser(user);
        return user;
      } catch (_) {
        return UserModel.fromJson(response.data);
      }
    } on DioException catch (e) {
      throw Exception(_extractApiErrorMessage(e.response?.data, fallbackMessage: 'Update failed'));
    }
  }

  Future<UserModel> updateAvatar({
    required String userId,
    required List<int> imageBytes,
    required String fileName,
  }) async {
    final formData = FormData.fromMap({
      'avatar_file': MultipartFile.fromBytes(
        imageBytes,
        filename: fileName,
      ),
    });

    try {
      final response = await dio.post<dynamic>(
        'users/$userId/avatar',
        data: formData,
      );
      final user = UserModel.fromJson(response.data);
      _cachedUserId = user.id;
      await _persistCachedUser(user);
      return user;
    } on DioException catch (e) {
      throw Exception(_extractApiErrorMessage(e.response?.data, fallbackMessage: 'Avatar upload failed'));
    }
  }

  Future<AuthSessionModel?> restoreSession() async {
    final accessToken = await storage.read(key: accessTokenStorageKey);
    if (accessToken == null || accessToken.isEmpty) {
      return null;
    }

    final refreshToken = await storage.read(key: refreshTokenStorageKey);
    final cachedUserJson = await storage.read(key: userCacheStorageKey);
    UserModel? user;
    if (cachedUserJson != null && cachedUserJson.isNotEmpty) {
      try {
        user = UserModel.fromJson(jsonDecode(cachedUserJson));
        _cachedUserId = user.id;
      } catch (_) {
        user = null;
      }
    }

    return AuthSessionModel(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user,
    );
  }

  Future<String?> accessToken() {
    return storage.read(key: accessTokenStorageKey);
  }

  String? get currentUserId => _cachedUserId;

  Future<void> logout() async {
    _cachedUserId = null;
    const keys = [
      'stratos_access_token',
      'stratos_refresh_token',
      'stratos_cached_user',
      'access_token',
      'token',
      'auth_token',
      'jwt',
    ];
    for (final key in keys) {
      await storage.delete(key: key);
    }
  }

  Future<void> _persistSession(AuthSessionModel session) async {
    if (session.accessToken.isNotEmpty) {
      await storage.write(
        key: accessTokenStorageKey,
        value: session.accessToken,
      );
    }
    if (session.refreshToken != null && session.refreshToken!.isNotEmpty) {
      await storage.write(
        key: refreshTokenStorageKey,
        value: session.refreshToken,
      );
    } else {
      await storage.delete(key: refreshTokenStorageKey);
    }
    if (session.user != null) {
      await _persistCachedUser(session.user!);
    }
  }

  Future<void> _persistCachedUser(UserModel user) async {
    await storage.write(
      key: userCacheStorageKey,
      value: jsonEncode(user.toJson()),
    );
  }

  String _extractApiErrorMessage(
    dynamic data, {
    required String fallbackMessage,
  }) {
    if (data is Map) {
      final detail = data['detail'];
      if (detail != null) {
        return detail.toString();
      }
      final message = data['message'];
      if (message != null) {
        return message.toString();
      }
    }
    return fallbackMessage;
  }
}
