import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/core/theme/app_theme.dart';
import 'package:seedrover/core/theme/app_typography.dart';

void main() {
  test('shared typography uses the bundled Karla, Poppins, and Nunito roles',
      () {
    final theme = AppTheme.light;

    expect(theme.textTheme.bodyLarge?.fontFamily, 'Karla');
    expect(theme.primaryTextTheme.bodyLarge?.fontFamily, 'Karla');
    expect(theme.textTheme.headlineLarge?.fontFamily, 'Poppins');
    expect(theme.datePickerTheme.dayStyle?.fontFamily, 'Nunito');
    expect(theme.popupMenuTheme.textStyle?.fontFamily, 'Karla');
    expect(AppTypography.body.fontFamily, 'Karla');
    expect(AppTypography.screenTitle.fontFamily, 'Poppins');
    expect(AppTypography.sectionHeading.fontFamily, 'Poppins');
    expect(AppTypography.numericValue.fontFamily, 'Nunito');
    expect(AppTypography.numericInput.fontFamily, 'Nunito');
    expect(
      AppTypography.numericValue.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets(
      'long numeric values remain readable at narrow width and large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dashboard', style: AppTypography.screenTitle),
                  Text(
                    '₱1,234,567,890.00',
                    style: AppTypography.numericValue,
                    softWrap: true,
                  ),
                  Text('Sensor reading 28.5 °C',
                      style: AppTypography.numericCaption),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('₱1,234,567,890.00'), findsOneWidget);
  });
}
