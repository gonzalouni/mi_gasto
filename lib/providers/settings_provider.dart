import 'package:flutter/material.dart';

import '../db/database_helper.dart';

class SettingsProvider extends ChangeNotifier {
  String currency = 'PEN';
  ThemeMode themeMode = ThemeMode.system;

  // Día del mes en que empieza el periodo presupuestal (día de pago).
  int payDay = 1;

  Future<void> load() async {
    currency = await DatabaseHelper.instance.getSetting('currency') ?? 'PEN';
    payDay = int.tryParse(
            await DatabaseHelper.instance.getSetting('payDay') ?? '') ??
        1;
    final theme = await DatabaseHelper.instance.getSetting('themeMode');
    if (theme == 'light') {
      themeMode = ThemeMode.light;
    } else if (theme == 'dark') {
      themeMode = ThemeMode.dark;
    } else {
      themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setCurrency(String value) async {
    currency = value;
    notifyListeners();
    await DatabaseHelper.instance.setSetting('currency', value);
  }

  Future<void> setPayDay(int value) async {
    payDay = value.clamp(1, 31);
    notifyListeners();
    await DatabaseHelper.instance.setSetting('payDay', '$payDay');
  }

  Future<void> setThemeMode(ThemeMode value) async {
    themeMode = value;
    notifyListeners();
    final key = switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await DatabaseHelper.instance.setSetting('themeMode', key);
  }
}
