import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const Color kIncomeColor = Color(0xFF0F766E);
const Color kExpenseColor = Color(0xFFDC2626);

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

  /// Light palette — bám sát brand kit: mint bg #EFFCF9, teal #005E5D
  static const light = AppThemeColors(
    bgCanvas: Color(0xFFF4FAF9), // pha mint nhẹ, không trắng tinh
    bgSurface: Color(0xFFFFFFFF),
    bgElevated: Color(0xFFEEF7F5),
    textPrimary: Color(0xFF071F31), // navy brand
    textSecondary: Color(0xFF445D6E),
    textMuted: Color(0xFF526D7A),
    primaryAccent: Color(0xFF005E5D), // deep teal brand
    borderSubtle: Color(0xFFD6EBEA),
    borderProminent: Color(0xFFADD4D0),
    income: Color(0xFF00796B),
    expense: Color(0xFFBF360C),
    warning: Color(0xFF8F6000),
  );

  /// Dark palette — teal sáng hơn trên nền navy
  static const dark = AppThemeColors(
    bgCanvas: Color(0xFF071217),
    bgSurface: Color(0xFF0D1E21),
    bgElevated: Color(0xFF132A2E),
    textPrimary: Color(0xFFECF5F4),
    textSecondary: Color(0xFF8FBAB5),
    textMuted: Color(0xFF8CAAA5),
    primaryAccent: Color(0xFF4DD9C8), // teal sáng
    borderSubtle: Color(0xFF1A3035),
    borderProminent: Color(0xFF244248),
    income: Color(0xFF4DD9C8),
    expense: Color(0xFFFF6E6E),
    warning: Color(0xFFFFCA28),
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

/// Named color constants used across the Quản lý PMV UI.
class PmvColors {
  PmvColors._();

  static const Color seed = Color(0xFF005E5D);
  static const Color income = Color(0xFF00796B);
  static const Color expense = Color(0xFFBF360C);
  static const Color transfer = Color(0xFF546E7A);
  static const Color debtActive = Color(0xFF1565C0);
  static const Color debtPartial = Color(0xFF6A1B9A);
  static const Color debtPaid = Color(0xFF2E7D32);
  static const Color debtCancelled = Color(0xFF757575);

  // Brand kit
  static const Color brandTeal = Color(0xFF005E5D);
  static const Color brandMint = Color(0xFFEFFCF9);
  static const Color brandNavy = Color(0xFF071F31);
  static const Color brandGreen = Color(0xFF42C245);
  static const Color brandGold = Color(0xFFECB02E);
}

ThemeData financeTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final colors = isDark ? AppThemeColors.dark : AppThemeColors.light;

  // Thiết lập SystemUiOverlayStyle phù hợp với One UI Samsung
  final systemOverlay = isDark
      ? SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: colors.bgCanvas,
          systemNavigationBarIconBrightness: Brightness.light,
        )
      : SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: colors.bgCanvas,
          systemNavigationBarIconBrightness: Brightness.dark,
        );

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: colors.primaryAccent,
    onPrimary: isDark ? const Color(0xFF071217) : Colors.white,
    primaryContainer: isDark
        ? const Color(0xFF0D3030)
        : const Color(0xFFB2DFDB),
    onPrimaryContainer: isDark
        ? const Color(0xFF80CBC4)
        : const Color(0xFF004D40),
    secondary: colors.primaryAccent,
    onSecondary: isDark ? const Color(0xFF071217) : Colors.white,
    secondaryContainer: isDark
        ? const Color(0xFF0F2A2D)
        : const Color(0xFFCCEEEB),
    onSecondaryContainer: isDark
        ? const Color(0xFF80CBC4)
        : const Color(0xFF004D40),
    tertiary: PmvColors.brandGold,
    onTertiary: isDark ? Colors.black : Colors.white,
    error: colors.expense,
    onError: Colors.white,
    surface: colors.bgSurface,
    onSurface: colors.textPrimary,
    onSurfaceVariant: colors.textSecondary,
    surfaceContainerHighest: colors.bgElevated,
    surfaceContainerHigh: isDark
        ? const Color(0xFF162426)
        : const Color(0xFFE8F5F3),
    surfaceContainer: colors.bgElevated,
    surfaceContainerLow: colors.bgSurface,
    surfaceContainerLowest: colors.bgCanvas,
    outline: colors.borderProminent,
    outlineVariant: colors.borderSubtle,
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: isDark ? colors.textPrimary : colors.bgCanvas,
    onInverseSurface: isDark ? colors.bgCanvas : colors.textPrimary,
    inversePrimary: isDark ? const Color(0xFF005E5D) : const Color(0xFF4DD9C8),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colors.bgCanvas,

    // ── Typography ────────────────────────────────────────────────────────────
    // Dùng font mặc định hệ thống (Roboto / Samsung One UI font);
    // fontFeatures tabular được áp riêng qua MoneyText và các widget tiền.
    textTheme: TextTheme(
      // Display
      displayLarge: TextStyle(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        letterSpacing: -0.25,
      ),
      displayMedium: TextStyle(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
      ),
      displaySmall: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
      ),
      // Headline
      headlineLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        letterSpacing: -0.5,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        letterSpacing: -0.25,
      ),
      headlineSmall: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
      ),
      // Title
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        letterSpacing: 0.1,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colors.textPrimary,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
        letterSpacing: 0.1,
      ),
      // Body
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: colors.textPrimary,
        letterSpacing: 0.25,
        height: 1.43,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: colors.textSecondary,
        letterSpacing: 0.4,
        height: 1.33,
      ),
      // Label
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: colors.textSecondary,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: colors.textMuted,
        letterSpacing: 0.5,
      ),
    ),

    // ── AppBar ────────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: colors.bgCanvas,
      foregroundColor: colors.textPrimary,
      shadowColor: colors.borderSubtle,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
        letterSpacing: 0,
      ),
      systemOverlayStyle: systemOverlay,
      iconTheme: IconThemeData(color: colors.textSecondary, size: 24),
      actionsIconTheme: IconThemeData(color: colors.textSecondary, size: 24),
    ),

    // ── NavigationBar (bottom) ────────────────────────────────────────────────
    navigationBarTheme: NavigationBarThemeData(
      elevation: 0,
      height: 64,
      backgroundColor: colors.bgSurface,
      indicatorColor: colors.primaryAccent.withValues(alpha: 0.12),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return IconThemeData(color: colors.primaryAccent, size: 24);
        }
        return IconThemeData(color: colors.textMuted, size: 24);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: colors.primaryAccent,
          );
        }
        return TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          color: colors.textMuted,
        );
      }),
      surfaceTintColor: Colors.transparent,
    ),

    // ── Card ─────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.borderSubtle, width: 1),
      ),
      color: colors.bgSurface,
      surfaceTintColor: Colors.transparent,
    ),

    // ── Input / TextFormField ─────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? colors.bgElevated : colors.bgSurface,
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
        borderSide: BorderSide(color: colors.primaryAccent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: colors.expense, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: colors.expense, width: 2),
      ),
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
      hintStyle: TextStyle(color: colors.textMuted, fontSize: 14),
      floatingLabelStyle: TextStyle(
        color: colors.primaryAccent,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),

    // ── FilledButton ──────────────────────────────────────────────────────────
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primaryAccent,
        foregroundColor: isDark ? const Color(0xFF071217) : Colors.white,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        elevation: 0,
      ),
    ),

    // ── OutlinedButton ────────────────────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primaryAccent,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        side: BorderSide(color: colors.primaryAccent, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ),

    // ── TextButton ────────────────────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primaryAccent,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
      ),
    ),

    // ── FloatingActionButton ──────────────────────────────────────────────────
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.primaryAccent,
      foregroundColor: isDark ? const Color(0xFF071217) : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),

    // ── Chip ─────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: colors.bgElevated,
      selectedColor: colors.primaryAccent.withValues(alpha: 0.15),
      side: BorderSide(color: colors.borderSubtle),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: colors.textPrimary,
      ),
      secondaryLabelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colors.primaryAccent,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),

    // ── ListTile ─────────────────────────────────────────────────────────────
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minVerticalPadding: 12,
      minLeadingWidth: 24,
      tileColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),

    // ── Divider ───────────────────────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: colors.borderSubtle,
      thickness: 1,
      space: 1,
    ),

    // ── SnackBar ──────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark
          ? const Color(0xFF1E3A3A)
          : const Color(0xFF0D2B2B),
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      actionTextColor: const Color(0xFF4DD9C8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
    ),

    // ── Dialog ───────────────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: colors.bgSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: colors.textPrimary,
      ),
      contentTextStyle: TextStyle(
        fontSize: 14,
        color: colors.textSecondary,
        height: 1.5,
      ),
    ),

    // ── BottomSheet ───────────────────────────────────────────────────────────
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.bgSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 4,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      dragHandleColor: colors.borderProminent,
      dragHandleSize: const Size(40, 4),
      showDragHandle: true,
    ),

    // ── ProgressIndicator ─────────────────────────────────────────────────────
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.primaryAccent,
      linearTrackColor: colors.borderSubtle,
      circularTrackColor: colors.borderSubtle,
    ),

    // ── Switch ────────────────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return isDark ? const Color(0xFF071217) : Colors.white;
        }
        return colors.textMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.primaryAccent;
        return colors.borderSubtle;
      }),
    ),

    // ── Badge ─────────────────────────────────────────────────────────────────
    badgeTheme: BadgeThemeData(
      backgroundColor: colors.expense,
      textColor: Colors.white,
      smallSize: 8,
    ),

    extensions: [colors],
    visualDensity: VisualDensity.standard,
  );
}
