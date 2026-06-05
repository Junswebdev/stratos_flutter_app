import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../data/dio_client.dart';

class AppSettings {
  final bool pushNotifications;
  final bool biometricAuth;
  final String language;

  const AppSettings({
    this.pushNotifications = true,
    this.biometricAuth = false,
    this.language = 'en',
  });

  AppSettings copyWith({
    bool? pushNotifications,
    bool? biometricAuth,
    String? language,
  }) {
    return AppSettings(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      biometricAuth: biometricAuth ?? this.biometricAuth,
      language: language ?? this.language,
    );
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  late final FlutterSecureStorage _storage;
  static const _keyNotifications = 'settings_notifications';
  static const _keyBiometric = 'settings_biometric';
  static const _keyLanguage = 'settings_language';

  @override
  AppSettings build() {
    _storage = ref.watch(secureStorageProvider);
    unawaited(_loadSettings());
    return const AppSettings();
  }

  Future<void> _loadSettings() async {
    final notifications = await _storage.read(key: _keyNotifications);
    final biometric = await _storage.read(key: _keyBiometric);
    final language = await _storage.read(key: _keyLanguage);

    state = state.copyWith(
      pushNotifications: notifications == null ? true : notifications == 'true',
      biometricAuth: biometric == 'true',
      language: language ?? 'en',
    );
  }

  Future<void> setNotifications(bool value) async {
    await _storage.write(key: _keyNotifications, value: value.toString());
    state = state.copyWith(pushNotifications: value);
  }

  Future<void> setBiometric(bool value) async {
    await _storage.write(key: _keyBiometric, value: value.toString());
    state = state.copyWith(biometricAuth: value);
  }

  Future<void> setLanguage(String value) async {
    await _storage.write(key: _keyLanguage, value: value);
    state = state.copyWith(language: value);
  }

  Future<void> resetToDefaults() async {
    await _storage.delete(key: _keyNotifications);
    await _storage.delete(key: _keyBiometric);
    await _storage.delete(key: _keyLanguage);
    state = const AppSettings();
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(() {
  return AppSettingsNotifier();
});
