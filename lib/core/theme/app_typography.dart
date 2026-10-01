import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTypography {
  const AppTypography._();

  static TextStyle get displayHeading => _poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        color: AppColors.primaryText,
      );

  static TextStyle get screenTitle => _poppins(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        color: AppColors.primaryText,
      );

  static TextStyle get sectionHeading => _poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 25 / 18,
        color: AppColors.primaryText,
      );

  static TextStyle get cardTitle => _karla(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 24 / 18,
        color: AppColors.primaryText,
      );

  static TextStyle get body => _karla(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 22 / 16,
        color: AppColors.primaryText,
      );

  static TextStyle get small => _karla(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: AppColors.secondaryText,
      );

  static TextStyle get caption => _karla(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: AppColors.mutedText,
      );

  static TextStyle get numericSmall => _nunito(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 18 / 13,
        color: AppColors.secondaryText,
      );

  static TextStyle get numericInput => _nunito(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 23 / 16,
        color: AppColors.primaryText,
      );

  static TextStyle get numericCaption => _nunito(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: AppColors.mutedText,
      );

  static TextStyle get numericValue => _nunito(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 24 / 18,
        color: AppColors.primaryText,
      );

  static TextStyle get statusBadge => _karla(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.8,
        color: AppColors.primaryText,
      );

  static TextStyle _karla({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    required Color color,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'Karla',
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
        fontVariations: [_weight(fontWeight)],
      );

  static TextStyle _poppins({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    required Color color,
  }) =>
      TextStyle(
        fontFamily: 'Poppins',
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        color: color,
      );

  static TextStyle _nunito({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    required Color color,
  }) =>
      TextStyle(
        fontFamily: 'Nunito',
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
        fontVariations: [_weight(fontWeight)],
      );

  static FontVariation _weight(FontWeight fontWeight) {
    if (fontWeight == FontWeight.w100) return const FontVariation('wght', 100);
    if (fontWeight == FontWeight.w200) return const FontVariation('wght', 200);
    if (fontWeight == FontWeight.w300) return const FontVariation('wght', 300);
    if (fontWeight == FontWeight.w500) return const FontVariation('wght', 500);
    if (fontWeight == FontWeight.w600) return const FontVariation('wght', 600);
    if (fontWeight == FontWeight.w700) return const FontVariation('wght', 700);
    if (fontWeight == FontWeight.w800) return const FontVariation('wght', 800);
    if (fontWeight == FontWeight.w900) return const FontVariation('wght', 900);
    return const FontVariation('wght', 400);
  }
}
