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

  static TextStyle get cardTitle => _poppins(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 24 / 18,
        color: AppColors.primaryText,
      );

  static TextStyle get body => _poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 22 / 16,
        color: AppColors.primaryText,
      );

  static TextStyle get small => _poppins(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        color: AppColors.secondaryText,
      );

  static TextStyle get caption => _poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: AppColors.mutedText,
      );

  static TextStyle get numericSmall => _poppins(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 18 / 13,
        color: AppColors.secondaryText,
      );

  static TextStyle get numericInput => _poppins(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 23 / 16,
        color: AppColors.primaryText,
      );

  static TextStyle get numericCaption => _poppins(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: AppColors.mutedText,
      );

  static TextStyle get numericValue => _poppins(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 24 / 18,
        color: AppColors.primaryText,
      );

  static TextStyle get statusBadge => _poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.8,
        color: AppColors.primaryText,
      );

  static TextStyle _poppins({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    required Color color,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'Poppins',
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );
}
