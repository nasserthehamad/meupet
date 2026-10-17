import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Escolha do tema (menu ☰ › Tema | Modo): claro, escuro ou igual ao celular.
/// Fica salva no aparelho.
class ThemeController {
  static final mode = ValueNotifier<ThemeMode>(ThemeMode.light);
  static const _key = 'theme_mode';

  static Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      mode.value = switch (p.getString(_key)) {
        'dark' => ThemeMode.dark,
        'system' => ThemeMode.system,
        _ => ThemeMode.light,
      };
    } catch (_) {
      // Sem acesso ao armazenamento: fica no claro.
    }
  }

  static Future<void> set(ThemeMode m) async {
    mode.value = m;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, switch (m) { ThemeMode.dark => 'dark', ThemeMode.system => 'system', _ => 'light' });
    } catch (_) {}
  }

  static String label(ThemeMode m) => switch (m) {
        ThemeMode.dark => 'Escuro',
        ThemeMode.system => 'Igual ao celular',
        _ => 'Claro',
      };
}
