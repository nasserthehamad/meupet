import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const teal = Color(0xFF1B9AAA);
  static const tealDark = Color(0xFF137887);
  static const orange = Color(0xFFF08A24);
  static const purple = Color(0xFF7E5BD0);
  static const brown = Color(0xFF6B3E26);
  static const yellow = Color(0xFFFFD45C);
  static const bg = Color(0xFFEDEDED);
  static const card = Colors.white;
  static const text = Color(0xFF2F3A3D);
  static const muted = Color(0xFF8A9599);
  static const red = Color(0xFFE5484D);
  static const green = Color(0xFF5B8C2A);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      primary: AppColors.teal,
      secondary: AppColors.orange,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: GoogleFonts.poppins().fontFamily,
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.teal,
      elevation: 0,
      centerTitle: true,
    ),
  );
}

TextStyle logoStyle(double size, Color color) =>
    GoogleFonts.baloo2(fontSize: size, fontWeight: FontWeight.w800, color: color, height: 1);

TextStyle sectionStyle() =>
    GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.teal);

InputDecoration inputDeco(String label, {IconData? icon, String? hint, bool filledTeal = false}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, color: filledTeal ? Colors.white : AppColors.teal),
    filled: true,
    fillColor: filledTeal ? AppColors.teal : Colors.white,
    labelStyle: TextStyle(color: filledTeal ? Colors.white70 : AppColors.muted),
    floatingLabelStyle: TextStyle(color: filledTeal ? Colors.white : AppColors.teal),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: filledTeal ? AppColors.teal : const Color(0xFFDADFE1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: filledTeal ? AppColors.orange : AppColors.teal, width: 2),
    ),
  );
}
