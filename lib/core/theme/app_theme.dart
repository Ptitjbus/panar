import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class AppTheme {
  static TextTheme _buildTextTheme() {
    final londrina = GoogleFonts.londrinaSolid(fontWeight: FontWeight.w900);
    final inter = GoogleFonts.inter();

    return TextTheme(
      displayLarge: londrina.copyWith(fontSize: 56, color: AppColors.textPrimary),
      displayMedium: londrina.copyWith(fontSize: 48, color: AppColors.textPrimary),
      displaySmall: londrina.copyWith(fontSize: 40, color: AppColors.textPrimary),
      headlineLarge: londrina.copyWith(fontSize: 32, color: AppColors.textPrimary),
      headlineMedium: londrina.copyWith(fontSize: 26, color: AppColors.textPrimary),
      headlineSmall: londrina.copyWith(fontSize: 22, color: AppColors.textPrimary),
      titleLarge: inter.copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleMedium: inter.copyWith(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      titleSmall: inter.copyWith(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      bodyLarge: inter.copyWith(fontSize: 16, fontWeight: FontWeight.w300, color: AppColors.textPrimary),
      bodyMedium: inter.copyWith(fontSize: 14, fontWeight: FontWeight.w300, color: AppColors.textSecondary),
      bodySmall: inter.copyWith(fontSize: 12, fontWeight: FontWeight.w300, color: AppColors.textSecondary),
      labelLarge: inter.copyWith(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
      labelMedium: inter.copyWith(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
      labelSmall: inter.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
    );
  }

  static ThemeData get lightTheme {
    final textTheme = _buildTextTheme();
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.black,
        brightness: Brightness.light,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.textPrimary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        hintStyle: GoogleFonts.inter(color: AppColors.textSecondary, fontWeight: FontWeight.w300),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomAppBarTheme: const BottomAppBarThemeData(
        color: AppColors.surface,
        elevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
