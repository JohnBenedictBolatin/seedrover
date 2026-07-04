import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTypography {
  const AppTypography._();

  static TextStyle get displayHeading => GoogleFonts.robotoMono(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32,
        color: AppColors.primaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get screenTitle => GoogleFonts.robotoMono(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        height: 34 / 26,
        color: AppColors.primaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get sectionHeading => GoogleFonts.robotoMono(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: AppColors.primaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get cardTitle => GoogleFonts.robotoMono(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 24 / 18,
        color: AppColors.primaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get body => GoogleFonts.robotoMono(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 22 / 15,
        color: AppColors.primaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get small => GoogleFonts.robotoMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 18 / 13,
        color: AppColors.secondaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get caption => GoogleFonts.robotoMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: AppColors.mutedText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get monoSectionHeading => GoogleFonts.robotoMono(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
        color: AppColors.primaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get monoCardTitle => GoogleFonts.robotoMono(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 24 / 18,
        color: AppColors.primaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get monoSmall => GoogleFonts.robotoMono(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 18 / 13,
        color: AppColors.secondaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get monoCaption => GoogleFonts.robotoMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 16 / 12,
        color: AppColors.mutedText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get sensorValue => GoogleFonts.robotoMono(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        height: 24 / 18,
        color: AppColors.primaryText,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get statusBadge => GoogleFonts.robotoMono(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.8,
        color: AppColors.primaryText,
      );
}
