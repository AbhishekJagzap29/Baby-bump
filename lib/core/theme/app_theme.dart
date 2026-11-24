import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.quicksandTextTheme();

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.warmCream,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.dustyRose,
        onPrimary: Colors.white,
        secondary: AppColors.lavender,
        onSecondary: AppColors.deepPlum,
        error: AppColors.errorRed,
        onError: Colors.white,
        surface: AppColors.cardSurface,
        onSurface: AppColors.deepPlum,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.quicksand(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.deepPlum,
        ),
        displayMedium: GoogleFonts.quicksand(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.deepPlum,
        ),
        titleLarge: GoogleFonts.quicksand(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.deepPlum,
        ),
        titleMedium: GoogleFonts.quicksand(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.deepPlum,
        ),
        bodyLarge: GoogleFonts.quicksand(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.deepPlum,
        ),
        bodyMedium: GoogleFonts.quicksand(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.plumTextSubtle,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.warmCream,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.quicksand(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.deepPlum,
        ),
        iconTheme: const IconThemeData(color: AppColors.deepPlum),
      ),
      cardTheme: CardTheme(
        color: AppColors.cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.dustyRose,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.shadowColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: GoogleFonts.quicksand(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.dustyRose, width: 2),
        ),
      ),
    );
  }
}
