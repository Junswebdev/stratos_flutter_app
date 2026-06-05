import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/dio_client.dart';

/// Simple provider to manage theme mode state across the app
final themeModeProvider = NotifierProvider<ThemeModeManager, ThemeMode>(
  ThemeModeManager.new,
);

class ThemeModeManager extends Notifier<ThemeMode> {
  static const _themeModeKey = 'settings_theme_mode';

  @override
  ThemeMode build() {
    final storage = ref.watch(secureStorageProvider);
    unawaited(() async {
      final raw = await storage.read(key: _themeModeKey);
      if (raw == null || raw.isEmpty) return;
      state = _parseMode(raw);
    }());
    return ThemeMode.system;
  }

  ThemeMode _parseMode(String value) {
    switch (value.toLowerCase().trim()) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> _persist(ThemeMode mode) async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: _themeModeKey, value: mode.name);
  }

  void toggle() {
    state = switch (state) {
      ThemeMode.system => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.light,
      ThemeMode.light => ThemeMode.system,
    };
    unawaited(_persist(state));
  }

  void setDark() {
    state = ThemeMode.dark;
    unawaited(_persist(state));
  }

  void setLight() {
    state = ThemeMode.light;
    unawaited(_persist(state));
  }

  void setSystem() {
    state = ThemeMode.system;
    unawaited(_persist(state));
  }

  String get nextModeName {
    return switch (state) {
      ThemeMode.system => 'Dark',
      ThemeMode.dark => 'Light',
      ThemeMode.light => 'System',
    };
  }

  IconData get icon {
    return switch (state) {
      ThemeMode.system => Icons.brightness_auto,
      ThemeMode.dark => Icons.dark_mode,
      ThemeMode.light => Icons.light_mode,
    };
  }
}
