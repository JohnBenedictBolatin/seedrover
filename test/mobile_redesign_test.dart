import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/core/theme/app_theme.dart';
import 'package:seedrover/core/theme/app_colors.dart';
import 'package:seedrover/shared/widgets/app_page_header.dart';
import 'package:seedrover/shared/widgets/compact_search_filter_bar.dart';
import 'package:seedrover/shared/widgets/rovie_scene.dart';
import 'package:seedrover/shared/widgets/seedrover_mascot.dart';
import 'package:seedrover/features/crops/data/models/crop_model.dart';
import 'package:seedrover/features/crops/presentation/widgets/planted_crop_group.dart';
import 'package:seedrover/features/crops/presentation/widgets/crop_overview_hero.dart';
import 'package:seedrover/features/crops/presentation/widgets/crop_history_button.dart';
import 'package:seedrover/features/crops/presentation/widgets/crop_detail_panel.dart';
import 'package:seedrover/features/crops/presentation/widgets/crop_growth_progress.dart';
import 'package:seedrover/features/crops/presentation/screens/crop_sensor_history_screen.dart';
import 'package:seedrover/features/crops/providers/crop_providers.dart';

void main() {
  testWidgets('shared mobile header and Rovie briefing fit common phone widths',
      (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final width in [320.0, 390.0, 430.0]) {
        await tester.binding.setSurfaceSize(Size(width, 760));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: brightness == Brightness.light
                ? ThemeMode.light
                : ThemeMode.dark,
            builder: (context, child) {
              AppColors.useLightPalette(
                Theme.of(context).brightness == Brightness.light,
              );
              return child ?? const SizedBox.shrink();
            },
            home: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  AppPageHeader(title: 'Crops'),
                  SizedBox(height: 16),
                  RovieScene(
                    title: 'Field check-in',
                    message: 'Two crop care tasks are ready when you are.',
                    expression: SeedRoverMascotExpression.thinking,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Crops'), findsOneWidget);
        expect(find.text('Field check-in'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('compact crop rows fit common widths, themes, and large text',
      (tester) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final width in [320.0, 390.0, 430.0]) {
        await tester.binding.setSurfaceSize(Size(width, 760));
        CropModel? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: brightness == Brightness.light
                ? ThemeMode.light
                : ThemeMode.dark,
            builder: (context, child) {
              AppColors.useLightPalette(
                Theme.of(context).brightness == Brightness.light,
              );
              return MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: PlantedCropGroup(
                  title: 'Sitaw (1)',
                  crops: [_testCrop()],
                  onCropSelected: (crop) => selected = crop,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Recorded stage: Vegetative'), findsOneWidget);
        expect(find.text('Overdue: Water the batch'), findsOneWidget);
        await tester.tap(find.byType(InkWell).last);
        expect(selected?.id, 'crop-1');
        expect(tester.takeException(), isNull);
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('crop landing and details surfaces render in light and dark',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final view in ['landing', 'details']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: brightness == Brightness.light
                ? ThemeMode.light
                : ThemeMode.dark,
            builder: (context, child) {
              AppColors.useLightPalette(
                Theme.of(context).brightness == Brightness.light,
              );
              return child ?? const SizedBox.shrink();
            },
            home: Scaffold(
              backgroundColor: AppColors.primaryBackground,
              body: SafeArea(
                child: view == 'landing'
                    ? ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const AppPageHeader(title: 'Crops'),
                          const SizedBox(height: 16),
                          const CropOverviewHero(activeCrops: 8),
                          const SizedBox(height: 8),
                          CropHistoryButton(
                            onPressed: () {},
                          ),
                          const SizedBox(height: 20),
                          PlantedCropGroup(
                            title: 'Sitaw (1)',
                            crops: [_testCrop()],
                            onCropSelected: (_) {},
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          CropDetailPanel(
                            crop: _testCrop(),
                            onRecordCare: () {},
                          ),
                        ],
                      ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile('goldens/crops_${view}_${brightness.name}.png'),
        );
      }
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('crop overview balances planted-by and next-care cards',
      (tester) async {
    for (final width in [320.0, 390.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 760));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  CropDetailPanel(
                    crop: _testCrop(
                      careTaskTitle: 'Review fertilizer for Sitaw',
                    ),
                    onRecordCare: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('More crop details'), findsNothing);
      expect(find.text('Next care'), findsOneWidget);
      expect(find.text('Latest sensor check'), findsNothing);
      expect(find.text('Planted'), findsOneWidget);
      expect(find.text('Planted by'), findsOneWidget);
      expect(find.text('Review fertilizer'), findsOneWidget);
      expect(find.text('Review fertilizer for Sitaw'), findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('crop progress uses the configured plan and recorded stage',
      (tester) async {
    for (final width in [320.0, 390.0, 430.0]) {
      await tester.binding.setSurfaceSize(Size(width, 300));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: CropGrowthProgress(crop: _testCrop()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('60%'), findsOneWidget);
      expect(find.textContaining('Stage 3 of 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('crop progress stays unavailable without a matching plan stage',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: CropGrowthProgress(
            crop: _testCrop().copyWith(
              growthStage: CropGrowthStage.other,
              recordedGrowthStage: 'Unrecognized stage',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Progress unavailable'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sensor history labels stale, uncalibrated readings clearly',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cropSensorHistoryProvider('crop-1').overrideWith(
            (ref) async => [
              CropSensorReading(
                id: 'reading-1',
                recordedAt: DateTime(2026, 1, 1),
                source: 'SeedRover-01',
                provenanceStatus: 'unverified',
                soilRaw: 2010,
                soilMoistureCalibrated: false,
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: CropSensorHistoryScreen(cropId: 'crop-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stale'), findsOneWidget);
    expect(find.textContaining('Unverified source'), findsOneWidget);
    expect(find.textContaining('probe not calibrated'), findsOneWidget);
    expect(find.text('Unavailable'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
      'filter sheet applies choices and resets filters without clearing search',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    final hostKey = GlobalKey<_FilterTestHostState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) {
          AppColors.useLightPalette(true);
          return child ?? const SizedBox.shrink();
        },
        home: _FilterTestHost(key: hostKey),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const Key('compact-search-field')), 'sitaw');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-filter-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Low stock'));
    await tester.tap(find.text('Apply filters'));
    await tester.pumpAndSettle();

    expect(hostKey.currentState!.query, 'sitaw');
    expect(hostKey.currentState!.applied?['status'], 'low');

    await tester.tap(find.byKey(const Key('open-filter-sheet')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(hostKey.currentState!.query, 'sitaw');
    expect(hostKey.currentState!.applied?['status'], 'all');
    expect(tester.takeException(), isNull);
    await tester.binding.setSurfaceSize(null);
  });
}

CropModel _testCrop({String careTaskTitle = 'Water the batch'}) => CropModel(
      id: 'crop-1',
      batchCode: 'BATCH-01',
      name: 'Sitaw',
      variety: 'Pole bean',
      location: 'North plot',
      plantingDate: DateTime(2026, 8, 1),
      estimatedHarvest: DateTime(2026, 10, 1),
      growthStage: CropGrowthStage.vegetative,
      recordedGrowthStage: 'Vegetative',
      status: CropStatus.needsAttention,
      maintenanceNotes: const [],
      managerName: 'Leo',
      profileStages: const [
        'Seeded',
        'Germinating',
        'Vegetative',
        'Flowering',
        'Fruiting',
      ],
      sensorSnapshot: const CropSensorSnapshot(
        soilMoisture: null,
        soilTemperature: null,
        environmentTemperature: null,
        humidity: null,
      ),
      maintenanceHistory: const [],
      reminders: const [],
      notes: '',
      fieldLabel: 'North plot',
      careTasks: [
        CropCareTask(
          id: 'task-1',
          title: careTaskTitle,
          recommendation: 'Check soil moisture before watering.',
          type: 'water',
          dueAt: DateTime(2026, 9, 26),
          priority: 'Critical',
          status: 'Overdue',
        ),
      ],
    );

class _FilterTestHost extends StatefulWidget {
  const _FilterTestHost({super.key});

  @override
  State<_FilterTestHost> createState() => _FilterTestHostState();
}

class _FilterTestHostState extends State<_FilterTestHost> {
  String query = '';
  Map<String, String>? applied;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: CompactSearchFilterBar(
            searchQuery: query,
            onSearchChanged: (value) => setState(() => query = value),
            groups: [
              SearchFilterGroup(
                keyName: 'status',
                label: 'Stock status',
                initialValue: 'all',
                currentValue: applied?['status'] ?? 'all',
                options: const [
                  SearchFilterOption('all', 'All stock'),
                  SearchFilterOption('low', 'Low stock'),
                ],
              ),
            ],
            onApply: (value) => setState(() => applied = value),
          ),
        ),
      );
}
