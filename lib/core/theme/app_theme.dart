import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
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
              onPrimary: Colors.white,
              secondary: AppColors.sageSurface,
              onSecondary: AppColors.primaryText,
              surface: AppColors.secondaryBackground,
              onSurface: AppColors.primaryText,
              error: AppColors.danger,
              onError: Colors.white,
            )
          : ColorScheme.dark(
              primary: AppColors.primaryGreen,
              secondary: AppColors.sageSurface,
              onPrimary: const Color(0xFF102318),
              onSecondary: AppColors.primaryText,
              surface: AppColors.secondaryBackground,
              onSurface: AppColors.primaryText,
              error: AppColors.danger,
              onError: Colors.white,
            ),
      textTheme: _withAppFonts(base.textTheme).apply(
        bodyColor: AppColors.primaryText,
        displayColor: AppColors.primaryText,
      ),
      primaryTextTheme: _withAppFonts(base.primaryTextTheme),
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.inactiveBorder),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryBackground,
        foregroundColor: AppColors.primaryText,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        titleTextStyle: AppTypography.screenTitle,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: base.colorScheme.inverseSurface,
        contentTextStyle: AppTypography.body.copyWith(
          color: base.colorScheme.onInverseSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.inactiveBorder, width: 1.5),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        showCloseIcon: true,
        closeIconColor: base.colorScheme.onInverseSurface,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        titleTextStyle:
            AppTypography.sectionHeading.copyWith(color: AppColors.primaryText),
        contentTextStyle:
            AppTypography.body.copyWith(color: AppColors.secondaryText),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.inactiveBorder),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(textStyle: AppTypography.body),
      dropdownMenuTheme: DropdownMenuThemeData(textStyle: AppTypography.body),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.secondaryBackground,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: AppColors.secondaryBackground,
        headerForegroundColor: AppColors.primaryText,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        headerHeadlineStyle: AppTypography.sectionHeading,
        weekdayStyle: AppTypography.caption,
        dayStyle: AppTypography.numericCaption,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.secondaryBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        hourMinuteTextStyle: AppTypography.numericValue,
        helpTextStyle: AppTypography.caption,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.inactiveBorder,
        thickness: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            fontVariations: const [FontVariation('wght', 600)],
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          side: BorderSide(color: AppColors.inactiveBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: AppTypography.body.copyWith(
            fontWeight: FontWeight.w600,
            fontVariations: const [FontVariation('wght', 600)],
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: AppColors.secondaryBackground,
        indicatorColor: AppColors.sageSurface,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.secondaryGreen : AppColors.mutedText,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.caption.copyWith(
            color: selected ? AppColors.secondaryGreen : AppColors.mutedText,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            fontVariations: [
              FontVariation('wght', selected ? 700 : 500),
            ],
          );
        }),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        constraints: const BoxConstraints(minHeight: 48),
        labelStyle: AppTypography.body,
        helperStyle: AppTypography.small,
        errorStyle: AppTypography.small.copyWith(color: AppColors.danger),
        errorMaxLines: 3,
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
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.smd,
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
              ? AppColors.primaryGreen.withValues(alpha: .28)
              : AppColors.inactiveBorder,
        ),
      ),
    );
  }

  // Flutter 3.27 does not derive the variable-font weight axis from
  // FontWeight, so carry the text style's declared weight into the Karla face.
  static TextTheme _withAppFonts(TextTheme textTheme) {
    TextStyle? style(TextStyle? source, String family) {
      if (source == null) return null;
      return source.copyWith(
        fontFamily: family,
        fontVariations: family == 'Karla'
            ? [FontVariation('wght', _weightAxis(source.fontWeight))]
            : null,
      );
    }

    return textTheme.copyWith(
      displayLarge: style(textTheme.displayLarge, 'Poppins'),
      displayMedium: style(textTheme.displayMedium, 'Poppins'),
      displaySmall: style(textTheme.displaySmall, 'Poppins'),
      headlineLarge: style(textTheme.headlineLarge, 'Poppins'),
      headlineMedium: style(textTheme.headlineMedium, 'Poppins'),
      headlineSmall: style(textTheme.headlineSmall, 'Poppins'),
      titleLarge: style(textTheme.titleLarge, 'Poppins'),
      titleMedium: style(textTheme.titleMedium, 'Karla'),
      titleSmall: style(textTheme.titleSmall, 'Karla'),
      bodyLarge: style(textTheme.bodyLarge, 'Karla'),
      bodyMedium: style(textTheme.bodyMedium, 'Karla'),
      bodySmall: style(textTheme.bodySmall, 'Karla'),
      labelLarge: style(textTheme.labelLarge, 'Karla'),
      labelMedium: style(textTheme.labelMedium, 'Karla'),
      labelSmall: style(textTheme.labelSmall, 'Karla'),
    );
  }

  static double _weightAxis(FontWeight? weight) {
    if (weight == FontWeight.w100) return 100;
    if (weight == FontWeight.w200) return 200;
    if (weight == FontWeight.w300) return 300;
    if (weight == FontWeight.w500) return 500;
    if (weight == FontWeight.w600) return 600;
    if (weight == FontWeight.w700) return 700;
    if (weight == FontWeight.w800) return 800;
    if (weight == FontWeight.w900) return 800;
    return 400;
  }
}
