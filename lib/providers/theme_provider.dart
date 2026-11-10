import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';

enum MossThemeMode { system, light, dark, amoled }

extension MossThemeModeLabel on MossThemeMode {
  String get label => switch (this) {
        MossThemeMode.system => 'System',
        MossThemeMode.light => 'Light',
        MossThemeMode.dark => 'Dark',
        MossThemeMode.amoled => 'AMOLED black',
      };
}

class ThemeProvider extends ChangeNotifier {
  static const _modeKey = 'moss_theme_mode';
  static const _themeKey = 'moss_theme_id';

  MossThemeMode _mode = MossThemeMode.system;
  String _themeId = MossThemes.all.first.id;

  MossThemeMode get mode => _mode;
  String get themeId => _themeId;
  MossThemeDef get themeDef => MossThemes.byId(_themeId);

  ThemeData resolve(Brightness platform) {
    final dark = switch (_mode) {
      MossThemeMode.light => false,
      MossThemeMode.dark || MossThemeMode.amoled => true,
      MossThemeMode.system => platform == Brightness.dark,
    };
    return MossThemes.themeFor(
      themeDef,
      brightness: dark ? Brightness.dark : Brightness.light,
      amoled: _mode == MossThemeMode.amoled,
    );
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rawMode = prefs.getString(_modeKey) ??
        prefs.getString('moss_theme'); // v1.0 key — migrate once
    if (rawMode != null) {
      _mode = MossThemeMode.values.firstWhere(
        (m) => m.name == rawMode,
        orElse: () => MossThemeMode.system,
      );
    }
    final rawTheme = prefs.getString(_themeKey);
    if (rawTheme != null &&
        MossThemes.all.any((t) => t.id == rawTheme)) {
      _themeId = rawTheme;
    }
    notifyListeners();
  }

  Future<void> setMode(MossThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modeKey, mode.name);
  }

  Future<void> setTheme(String id) async {
    if (!MossThemes.all.any((t) => t.id == id)) return;
    _themeId = id;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, id);
  }

  Future<void> cycle() async {
    final next = MossThemeMode.values[
        (_mode.index + 1) % MossThemeMode.values.length];
    await setMode(next);
  }
}
