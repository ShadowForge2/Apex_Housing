import 'package:flutter/material.dart';
import 'theme_colors.dart';

class AppColors {
  static const primary = Color(0xFF8B5CF6);
  static const primaryLight = Color(0xFFA78BFA);
  static const primaryDark = Color(0xFF7C3AED);
  static const lightPurple = Color(0xFFDDD6FE);

  static const secondary = Color(0xFF6C63FF);
  static const accent = Color(0xFFFF6B6B);

  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFAFAFA);
  static const surfaceVariant = Color(0xFFF5F3FF);

  static const text = Color(0xFF111827);
  static const subtitle = Color(0xFF6B7280);
  static const hint = Color(0xFF9CA3AF);
  static const textWhite = Color(0xFFFFFFFF);

  static const textPrimary = text;
  static const textSecondary = subtitle;
  static const textHint = hint;

  static const success = Color(0xFF22C55E);
  static const successLight = Color(0xFFDCFCE7);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFEE2E2);
  static const info = Color(0xFF3B82F6);
  static const infoLight = Color(0xFFEFF6FF);

  static const border = Color(0xFFECECEC);
  static const borderLight = Color(0xFFF5F3FF);
  static const divider = Color(0xFFECECEC);

  static const statUsers = Color(0xFF3B82F6);
  static const statLandlords = Color(0xFF8B5CF6);
  static const statTenants = Color(0xFF10B981);
  static const statProperties = Color(0xFFF59E0B);
  static const statBookings = Color(0xFF06B6D4);
  static const statRevenue = Color(0xFF8B5CF6);
  static const statKyc = Color(0xFFEF4444);
  static const statDisputes = Color(0xFFEC4899);
}

class AppRadius {
  static const double xs = 4.0;
  static const double sm = 10.0;
  static const double md = 14.0;
  static const double lg = 18.0;
  static const double xl = 24.0;
  static const double xxl = 24.0;
  static const double round = 999.0;
  static const double pill = 100.0;

  static const BorderRadius xsAll = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius xxlAll = BorderRadius.all(Radius.circular(xxl));
}

class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;
}

class AppShadow {
  static List<BoxShadow> soft = [
    const BoxShadow(blurRadius: 18, color: Colors.black12),
  ];
  static List<BoxShadow> minimal = [
    const BoxShadow(blurRadius: 15, color: Colors.black12),
  ];
  static List<BoxShadow> card = [
    const BoxShadow(blurRadius: 12, color: Color(0x0D000000), spreadRadius: 0, offset: Offset(0, 4)),
  ];
}

class AppTheme {
  static const _baseText = TextStyle(
    fontFamily: 'Inter',
    decoration: TextDecoration.none,
    decorationColor: Colors.transparent,
  );

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: ThemeColors.light.background,
    primaryColor: AppColors.primary,
    fontFamily: 'Inter',
    extensions: const [ThemeColors.light],
    textTheme: TextTheme(
      displayLarge: _baseText.copyWith(color: AppColors.text),
      displayMedium: _baseText.copyWith(color: AppColors.text),
      displaySmall: _baseText.copyWith(color: AppColors.text),
      headlineLarge: _baseText.copyWith(color: AppColors.text),
      headlineMedium: _baseText.copyWith(color: AppColors.text),
      headlineSmall: _baseText.copyWith(color: AppColors.text),
      titleLarge: _baseText.copyWith(color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w700),
      titleMedium: _baseText.copyWith(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w600),
      titleSmall: _baseText.copyWith(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600),
      bodyLarge: _baseText.copyWith(color: AppColors.text, fontSize: 16),
      bodyMedium: _baseText.copyWith(color: AppColors.text, fontSize: 14),
      bodySmall: _baseText.copyWith(color: AppColors.subtitle, fontSize: 12),
      labelLarge: _baseText.copyWith(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w600),
      labelMedium: _baseText.copyWith(color: AppColors.subtitle, fontSize: 12),
      labelSmall: _baseText.copyWith(color: AppColors.hint, fontSize: 11),
    ),
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.primaryLight,
      error: AppColors.error,
      surface: AppColors.surface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: ThemeColors.light.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      shadowColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ThemeColors.light.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      hintStyle: const TextStyle(color: AppColors.hint, fontSize: 15, fontWeight: FontWeight.w400),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textWhite,
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.background,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.hint,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      showUnselectedLabels: true,
      selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
  );
}
