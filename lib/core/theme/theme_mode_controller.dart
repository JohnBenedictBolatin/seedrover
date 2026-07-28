import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeControllerProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController()..restore(),
);

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.dark);

  static const _storageKey = 'seedrover.theme_mode';

  Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_storageKey);
    state = value == ThemeMode.light.name ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> setLightMode(bool enabled) async {
    state = enabled ? ThemeMode.light : ThemeMode.dark;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageKey, state.name);
  }
}
