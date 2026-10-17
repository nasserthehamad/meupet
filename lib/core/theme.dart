import 'package:flutter/material.dart';

/// Cores do app. As da marca são fixas; as de fundo, cartões e textos mudam
/// no modo escuro ([dark] é definido pelo MaterialApp antes de desenhar).
class AppColors {
  static const teal = Color(0xFF1B9AAA);
  static const tealDark = Color(0xFF137887);
  static const orange = Color(0xFFF08A24);
  static const purple = Color(0xFF7E5BD0);
  static const brown = Color(0xFF6B3E26);
  static const yellow = Color(0xFFFFD45C);
  static const muted = Color(0xFF8A9599);
  static const red = Color(0xFFE5484D);
  static const green = Color(0xFF5B8C2A);

  static bool dark = false;

  /// Faixas cinza do "S" e fundo das telas.
  static Color get bg => dark ? const Color(0xFF121719) : const Color(0xFFE7E7E7);

  /// Faixas brancas, barra do topo, menu, cartões sobre faixa cinza.
  static Color get surface => dark ? const Color(0xFF1E2528) : Colors.white;

  /// Cartões sobre faixa branca, campos de busca, chips.
  static Color get surface2 => dark ? const Color(0xFF29323A) : const Color(0xFFF1F4F4);

  /// Fundo do Início (carrossel) e cartões dele.
  static Color get homeBg => dark ? const Color(0xFF161B1D) : const Color(0xFFDCDCDC);
  static Color get homeCard => dark ? const Color(0xFF242C30) : const Color(0xFFEEEEEE);

  /// Textos: principal, secundário (cinza) e forte (títulos manuscritos).
  static Color get text => dark ? const Color(0xFFE8EDEE) : const Color(0xFF2F3A3D);
  static Color get text2 => dark ? const Color(0xFFB4BEC1) : const Color(0xFF5B6366);
  static Color get textStrong => dark ? const Color(0xFFF1F4F5) : const Color(0xFF3E4446);

  /// Linhas e bordas suaves.
  static Color get line => dark ? const Color(0xFF34404A) : const Color(0xFFDADFE1);

  /// Mantido por compatibilidade.
  static Color get card => surface;
}

ThemeData buildTheme({bool dark = false}) {
  final bg = dark ? const Color(0xFF121719) : const Color(0xFFE7E7E7);
  final surface = dark ? const Color(0xFF1E2528) : Colors.white;
  final surface2 = dark ? const Color(0xFF29323A) : const Color(0xFFF1F4F4);
  final text = dark ? const Color(0xFFE8EDEE) : const Color(0xFF2F3A3D);
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: AppColors.teal,
      secondary: AppColors.orange,
      surface: surface,
      onSurface: text,
    ),
    scaffoldBackgroundColor: bg,
    canvasColor: surface,
    fontFamily: 'Poppins',
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: text, displayColor: text),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: AppColors.teal,
      elevation: 0,
      centerTitle: true,
    ),
    dialogTheme: DialogThemeData(backgroundColor: surface),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface, modalBackgroundColor: surface),
    chipTheme: base.chipTheme.copyWith(backgroundColor: surface2),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

/// Letra do logo "MEU PET+" (pincel), como no protótipo.
TextStyle logoStyle(double size, Color color) =>
    TextStyle(fontFamily: 'CaveatBrush', fontSize: size, color: color, height: 1);

/// Títulos manuscritos ("Carteirinha", "Histórico Clínico"...).
TextStyle scriptStyle(double size, Color color) =>
    TextStyle(fontFamily: 'Kaushan', fontSize: size, color: color, height: 1.1);

/// Textos arredondados (nomes de pets, números).
TextStyle roundStyle(double size, Color color, {FontWeight weight = FontWeight.w800}) =>
    TextStyle(fontFamily: 'Baloo2', fontSize: size, fontWeight: weight, color: color, height: 1);

TextStyle sectionStyle() =>
    const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.teal);

InputDecoration inputDeco(String label, {IconData? icon, String? hint, bool filledTeal = false}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, color: filledTeal ? Colors.white : AppColors.teal),
    filled: true,
    fillColor: filledTeal ? AppColors.teal : AppColors.surface,
    labelStyle: TextStyle(color: filledTeal ? Colors.white70 : AppColors.muted),
    // No campo azul do login o rótulo não sobe para a borda (ficava cortado):
    // ele funciona como texto de exemplo e o ícone mostra o que é cada campo.
    floatingLabelBehavior: filledTeal ? FloatingLabelBehavior.never : null,
    floatingLabelStyle: TextStyle(color: filledTeal ? Colors.white : AppColors.teal),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: filledTeal ? AppColors.teal : AppColors.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: filledTeal ? AppColors.orange : AppColors.teal, width: 2),
    ),
  );
}
