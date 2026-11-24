import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's theme mode. Light by default (never "follow the device"); dark
/// is an explicit, remembered choice.
final class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit({this.prefs, ThemeMode initial = ThemeMode.light}) : super(initial);

  static const prefsKey = 'theme_dark';

  final SharedPreferencesAsync? prefs;

  SharedPreferencesAsync get _store => prefs ?? SharedPreferencesAsync();

  /// Restores the saved choice (absent = light).
  Future<void> load() async {
    try {
      final dark = await _store.getBool(prefsKey) ?? false;
      emit(dark ? ThemeMode.dark : ThemeMode.light);
    } on Object {
      // Keep the light default if storage is unavailable.
    }
  }

  Future<void> setDark(bool dark) async {
    emit(dark ? ThemeMode.dark : ThemeMode.light);
    try {
      await _store.setBool(prefsKey, dark);
    } on Object {
      // Not persisted; still applied for this session.
    }
  }
}
