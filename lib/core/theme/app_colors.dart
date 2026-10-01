import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static bool _useLightPalette = true;

  static void useLightPalette(bool value) {
    _useLightPalette = value;
  }

  static bool get isLight => _useLightPalette;

  static Color get primaryBackground =>
      _useLightPalette ? const Color(0xFFFFFFFF) : const Color(0xFF121B16);
  static Color get secondaryBackground =>
      _useLightPalette ? const Color(0xFFFFFFFF) : const Color(0xFF1D2922);
  static Color get cardBackground =>
      _useLightPalette ? const Color(0xFFF0F4EB) : const Color(0xFF26352B);
  static Color get primaryBorder =>
      _useLightPalette ? const Color(0xFFDCE5D7) : const Color(0xFF405046);
  static Color get inactiveBorder =>
      _useLightPalette ? const Color(0xFFE5EADF) : const Color(0xFF36453A);
  static Color get primaryText =>
      _useLightPalette ? const Color(0xFF183329) : const Color(0xFFF0F4ED);
  static Color get secondaryText =>
      _useLightPalette ? const Color(0xFF506453) : const Color(0xFFBFCCBF);
  static Color get mutedText =>
      _useLightPalette ? const Color(0xFF687764) : const Color(0xFF9EAE9F);
  static Color get primaryGreen =>
      _useLightPalette ? const Color(0xFF246B45) : const Color(0xFF91C99D);
  static Color get secondaryGreen =>
      _useLightPalette ? const Color(0xFF1E5C3A) : const Color(0xFF78B887);
  static Color get accentGreen =>
      _useLightPalette ? const Color(0xFF3D8054) : const Color(0xFFA0D4A9);
  static Color get buttonGradientStart =>
      _useLightPalette ? const Color(0xFF185C36) : const Color(0xFF8BD5A6);
  static Color get buttonGradientEnd =>
      _useLightPalette ? const Color(0xFF216E43) : const Color(0xFF68B886);
  static Color get darkGradientStart =>
      _useLightPalette ? const Color(0xFF163D29) : const Color(0xFF234231);
  static Color get success =>
      _useLightPalette ? const Color(0xFF216E43) : const Color(0xFF8BD5A6);
  static Color get warning =>
      _useLightPalette ? const Color(0xFF9A6A00) : const Color(0xFFFFB000);
  static Color get danger =>
      _useLightPalette ? const Color(0xFFC62828) : const Color(0xFFFF3B30);
  static Color get information =>
      _useLightPalette ? const Color(0xFF1565C0) : const Color(0xFF2196F3);
  static List<Color> get soilMoistureGradient => const [
        Color(0xFF1769AA),
        Color(0xFF124B7B),
      ];
  static List<Color> get soilTemperatureGradient => const [
        Color(0xFF367B4F),
        Color(0xFF205638),
      ];
  static List<Color> get airTemperatureGradient => const [
        Color(0xFF9A5B14),
        Color(0xFF74400D),
      ];
  static List<Color> get humidityGradient => const [
        Color(0xFF76538F),
        Color(0xFF503569),
      ];
  static Color get sageSurface =>
      _useLightPalette ? const Color(0xFFE7F0DF) : const Color(0xFF2B4232);
  static Color get skySurface =>
      _useLightPalette ? const Color(0xFFE7F1F2) : const Color(0xFF263C40);
  static Color get sunSurface =>
      _useLightPalette ? const Color(0xFFF5EED8) : const Color(0xFF403922);
  static Color get lilacSurface =>
      _useLightPalette ? const Color(0xFFF0EAF4) : const Color(0xFF392F40);

  static List<Color> get heroGradientColors => _useLightPalette
      ? const [
          Color(0xFF286C48),
          Color(0xFF20583D),
          Color(0xFF183F32),
        ]
      : const [
          Color(0xFF284936),
          Color(0xFF20342B),
          Color(0xFF18251F),
        ];

  static Color get heroPrimaryText => const Color(0xFFFFFFFF);
  static Color get heroSecondaryText => const Color(0xFFEAF7E9);
  static Color get heroMutedText => const Color(0xBFEAF7E9);
  static Color get heroIconGreen => const Color(0xFF9FDCAD);
}
