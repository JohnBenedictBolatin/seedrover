import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static bool _useLightPalette = false;

  static void useLightPalette(bool value) {
    _useLightPalette = value;
  }

  static bool get isLight => _useLightPalette;

  static Color get primaryBackground =>
      _useLightPalette ? const Color(0xFFEEF5EA) : const Color(0xFF1B1B1B);
  static Color get secondaryBackground =>
      _useLightPalette ? const Color(0xFFFFFFFF) : const Color(0xFF252525);
  static Color get cardBackground =>
      _useLightPalette ? const Color(0xFFF6FBF3) : const Color(0xFF313131);
  static Color get primaryBorder =>
      _useLightPalette ? const Color(0x2E123C1B) : const Color(0xFF53D11E);
  static Color get inactiveBorder =>
      _useLightPalette ? const Color(0x1F123C1B) : const Color(0xFF505050);
  static Color get primaryText =>
      _useLightPalette ? const Color(0xFF123C1B) : const Color(0xFFFFFFFF);
  static Color get secondaryText =>
      _useLightPalette ? const Color(0xFF35533A) : const Color(0xFFD4D4D4);
  static Color get mutedText =>
      _useLightPalette ? const Color(0x9E123C1B) : const Color(0xFF9A9A9A);
  static Color get primaryGreen =>
      _useLightPalette ? const Color(0xFF1F7A2E) : const Color(0xFF53D11E);
  static Color get secondaryGreen =>
      _useLightPalette ? const Color(0xFF185F28) : const Color(0xFF2FAF3E);
  static Color get accentGreen =>
      _useLightPalette ? const Color(0xFF246F1F) : const Color(0xFF8DFF2A);
  static Color get buttonGradientStart =>
      _useLightPalette ? const Color(0xFF185F28) : const Color(0xFF188A11);
  static Color get buttonGradientEnd =>
      _useLightPalette ? const Color(0xFF1F7A2E) : const Color(0xFF7CFF28);
  static Color get darkGradientStart =>
      _useLightPalette ? const Color(0xFF123C1B) : const Color(0xFF0A4F08);
  static Color get success =>
      _useLightPalette ? const Color(0xFF1F7A2E) : const Color(0xFF41D75B);
  static Color get warning =>
      _useLightPalette ? const Color(0xFF9A6A00) : const Color(0xFFFFB000);
  static Color get danger =>
      _useLightPalette ? const Color(0xFFC62828) : const Color(0xFFFF3B30);
  static Color get information =>
      _useLightPalette ? const Color(0xFF1565C0) : const Color(0xFF2196F3);

  static List<Color> get heroGradientColors => _useLightPalette
      ? const [
          Color(0xFF1D6A31),
          Color(0xFF185729),
          Color(0xFF134820),
        ]
      : const [
          Color(0xFF213A25),
          Color(0xFF171B18),
          Color(0xFF111211),
        ];

  static Color get heroPrimaryText => const Color(0xFFFFFFFF);
  static Color get heroSecondaryText => const Color(0xFFEAF7E9);
  static Color get heroMutedText => const Color(0xBFEAF7E9);
  static Color get heroIconGreen => const Color(0xFF9BEF8B);
}
