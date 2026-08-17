import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppThemeMode { light, dark, system }

class ThemeState {
  final AppThemeMode themeMode;

  const ThemeState({this.themeMode = AppThemeMode.system});

  ThemeState copyWith({AppThemeMode? themeMode}) {
    return ThemeState(themeMode: themeMode ?? this.themeMode);
  }

  ThemeMode get resolvedThemeMode {
    switch (themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}

class ThemeNotifier extends StateNotifier<ThemeState> {
  ThemeNotifier() : super(const ThemeState());

  void setThemeMode(AppThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }

  void toggleTheme() {
    state = state.copyWith(
      themeMode: state.themeMode == AppThemeMode.light
          ? AppThemeMode.dark
          : AppThemeMode.light,
    );
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeState>((ref) {
  return ThemeNotifier();
});
