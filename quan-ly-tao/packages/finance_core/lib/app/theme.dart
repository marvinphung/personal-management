import 'package:flutter/material.dart';

const Color kIncomeColor = Color(0xFF1B873F);
const Color kExpenseColor = Color(0xFFD32F2F);

@immutable
class AppThemeColors extends ThemeExtension<AppThemeColors> {
  final Color bgCanvas;
  final Color bgSurface;
  final Color bgElevated;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primaryAccent;
  final Color borderSubtle;
  final Color borderProminent;
  final Color income;
  final Color expense;
  final Color warning;

  const AppThemeColors({
    required this.bgCanvas,
    required this.bgSurface,
    required this.bgElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primaryAccent,
    required this.borderSubtle,
    required this.borderProminent,
    required this.income,
    required this.expense,
    required this.warning,
  });

  static const light = AppThemeColors(
    bgCanvas: Color(0xFFF8F9FA),
    bgSurface: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFF1F5F9),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF64748B),
    primaryAccent: Color(0xFF0F766E),
    borderSubtle: Color(0xFFE2E8F0),
    borderProminent: Color(0xFFCBD5E1),
    income: Color(0xFF0F766E),
    expense: Color(0xFFDC2626),
    warning: Color(0xFFD97706),
  );

  static const dark = AppThemeColors(
    bgCanvas: Color(0xFF0B1313),
    bgSurface: Color(0xFF121E1E),
    bgElevated: Color(0xFF192A2A),
    textPrimary: Color(0xFFF1F5F9),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    primaryAccent: Color(0xFF2DD4BF),
    borderSubtle: Color(0xFF1F2E2E),
    borderProminent: Color(0xFF2D3F3F),
    income: Color(0xFF2DD4BF),
    expense: Color(0xFFF87171),
    warning: Color(0xFFFBBF24),
  );

  @override
  AppThemeColors copyWith({
    Color? bgCanvas,
    Color? bgSurface,
    Color? bgElevated,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? primaryAccent,
    Color? borderSubtle,
    Color? borderProminent,
    Color? income,
    Color? expense,
    Color? warning,
  }) {
    return AppThemeColors(
      bgCanvas: bgCanvas ?? this.bgCanvas,
      bgSurface: bgSurface ?? this.bgSurface,
      bgElevated: bgElevated ?? this.bgElevated,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      primaryAccent: primaryAccent ?? this.primaryAccent,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderProminent: borderProminent ?? this.borderProminent,
      income: income ?? this.income,
      expense: expense ?? this.expense,
      warning: warning ?? this.warning,
    );
  }

  @override
  AppThemeColors lerp(ThemeExtension<AppThemeColors>? other, double t) {
    if (other is! AppThemeColors) return this;
    return AppThemeColors(
      bgCanvas: Color.lerp(bgCanvas, other.bgCanvas, t)!,
      bgSurface: Color.lerp(bgSurface, other.bgSurface, t)!,
      bgElevated: Color.lerp(bgElevated, other.bgElevated, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primaryAccent: Color.lerp(primaryAccent, other.primaryAccent, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderProminent: Color.lerp(borderProminent, other.borderProminent, t)!,
      income: Color.lerp(income, other.income, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppThemeColorsExtension on BuildContext {
  AppThemeColors get colors =>
      Theme.of(this).extension<AppThemeColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppThemeColors.dark
          : AppThemeColors.light);
}

ThemeData financeTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? AppThemeColors.dark : AppThemeColors.light;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: colors.primaryAccent,
      onPrimary: isDark ? const Color(0xFF0B1313) : Colors.white,
      secondary: colors.primaryAccent,
      onSecondary: isDark ? const Color(0xFF0B1313) : Colors.white,
      error: colors.expense,
      onError: Colors.white,
      surface: colors.bgSurface,
      onSurface: colors.textPrimary,
      onSurfaceVariant: colors.textSecondary,
      surfaceContainerHighest: colors.bgElevated,
      outline: colors.borderProminent,
      outlineVariant: colors.borderSubtle,
    ),
    scaffoldBackgroundColor: colors.bgCanvas,
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colors.borderSubtle,
          width: 1,
        ),
      ),
      color: colors.bgSurface,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: colors.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: colors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: colors.primaryAccent, width: 1.5),
      ),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    extensions: [colors],
    visualDensity: VisualDensity.standard,
  );
}
