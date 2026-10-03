import 'package:flutter/material.dart';

const Color kIncomeColor = Color(0xFF1B873F);
const Color kExpenseColor = Color(0xFFD32F2F);

ThemeData financeTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF1B873F),
      brightness: brightness,
      surface: isDark ? const Color(0xFF16181A) : const Color(0xFFF9FAFB),
      surfaceContainerHighest: isDark ? const Color(0xFF24272B) : const Color(0xFFEDF0F3),
    ),
    scaffoldBackgroundColor: isDark ? const Color(0xFF101214) : const Color(0xFFF4F6F8),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark ? const Color(0xFF2D3136) : const Color(0xFFE2E6EA),
          width: 1,
        ),
      ),
      color: isDark ? const Color(0xFF1D2024) : Colors.white,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    visualDensity: VisualDensity.standard,
  );
}
