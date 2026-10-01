import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/core/theme/app_colors.dart';
import 'package:seedrover/core/theme/app_theme.dart';
import 'package:seedrover/features/dashboard/data/models/dashboard_model.dart';
import 'package:seedrover/features/dashboard/presentation/widgets/recent_activity_panel.dart';

void main() {
  testWidgets('recent activity View All opens a draggable bottom sheet',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) {
          AppColors.useLightPalette(true);
          return child ?? const SizedBox.shrink();
        },
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: RecentActivityPanel(
              activities: List.generate(
                7,
                (index) => ActivityPreviewModel(
                  title: 'Activity ${index + 1}',
                  description: 'A saved farm activity',
                  timestamp: DateTime(2026, 9, 26),
                  module: 'Crops',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('recent-activity-history-drag-handle')),
        findsOneWidget);
    expect(find.text('7 activity records'), findsOneWidget);
    expect(find.text('1–5 of 7 records'), findsOneWidget);
    expect(find.text('Activity 5'), findsOneWidget);
    expect(find.text('Activity 6'), findsNothing);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('6–7 of 7 records'), findsOneWidget);
    expect(find.text('Activity 6'), findsOneWidget);

    await tester.fling(
      find.byKey(const Key('recent-activity-history-drag-handle')),
      const Offset(0, 700),
      1200,
    );
    await tester.pumpAndSettle();
    expect(find.text('7 activity records'), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });
}
