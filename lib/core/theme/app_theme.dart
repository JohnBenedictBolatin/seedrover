import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get light {
    AppColors.useLightPalette(true);
    final base = ThemeData.light(useMaterial3: true);
    return _build(base);
  }

  static ThemeData get dark {
    AppColors.useLightPalette(false);
    final base = ThemeData.dark(useMaterial3: true);
    return _build(base);
  }

  static ThemeData _build(ThemeData base) {
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.primaryBackground,
      colorScheme: AppColors.isLight
          ? ColorScheme.light(
              primary: AppColors.primaryGreen,
              secondary: AppColors.accentGreen,
              surface: AppColors.secondaryBackground,
              error: AppColors.danger,
            )
          : ColorScheme.dark(
              primary: AppColors.primaryGreen,
              secondary: AppColors.accentGreen,
              surface: AppColors.secondaryBackground,
              error: AppColors.danger,
            ),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
        bodyColor: AppColors.primaryText,
        displayColor: AppColors.primaryText,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.primaryBorder),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryBackground,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        titleTextStyle: AppTypography.screenTitle,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.secondaryBackground,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTypography.sectionHeading.copyWith(color: AppColors.primaryText),
        contentTextStyle: AppTypography.body.copyWith(color: AppColors.secondaryText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.primaryBorder),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.inactiveBorder,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.secondaryBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.inactiveBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.inactiveBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.primaryBorder),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryGreen
              : AppColors.mutedText,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primaryGreen.withOpacity(.28)
              : AppColors.inactiveBorder,
        ),
      ),
    );
  }
}
