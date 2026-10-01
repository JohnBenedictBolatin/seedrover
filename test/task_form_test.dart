import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/core/theme/app_theme.dart';
import 'package:seedrover/shared/widgets/action_confirmation.dart';
import 'package:seedrover/shared/widgets/app_selector.dart';
import 'package:seedrover/shared/widgets/task_form.dart';

Future<void> openForm(WidgetTester tester, TaskForm Function() form) async {
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => showTaskForm(context, form()),
                  child: const Text('Open task'))))));
  await tester.tap(find.text('Open task'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('failed saves retain input and repeated taps submit only once',
      (tester) async {
    final pending = Completer<ActionOutcome>();
    var submissions = 0;
    await openForm(tester, () {
      final controller = TextEditingController();
      return TaskForm(
          title: 'Watering',
          submitLabel: 'Save watering',
          controllers: [controller],
          builder: (_, __) => TextFormField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Amount')),
          onSubmit: () {
            submissions++;
            return pending.future;
          });
    });
    await tester.enterText(find.byType(TextFormField), '12.5');
    await tester.tap(find.text('Save watering'));
    await tester.pump();
    await tester.tap(find.text('Saving…'));
    await tester.pump();
    expect(submissions, 1);
    pending.complete(const ActionOutcome.failure('Could not save. Try again.'));
    await tester.pumpAndSettle();
    expect(find.text('12.5'), findsOneWidget);
    expect(find.text('Could not save. Try again.'), findsOneWidget);
    expect(find.text('Save watering'), findsOneWidget);
  });

  testWidgets('review never submits and editing retains values',
      (tester) async {
    var submissions = 0;
    await openForm(tester, () {
      final controller = TextEditingController(text: '24');
      return TaskForm(
          title: 'Adjust quantity',
          submitLabel: 'Adjust quantity',
          controllers: [controller],
          builder: (_, __) => TextFormField(controller: controller),
          reviewBuilder: () =>
              ReviewDetails(values: {'New total': controller.text}),
          onSubmit: () async {
            submissions++;
            return const ActionOutcome.success();
          });
    });
    await tester.enterText(find.byType(TextFormField), '19');
    await tester.tap(find.text('Review details'));
    await tester.pumpAndSettle();
    expect(submissions, 0);
    expect(find.text('19'), findsOneWidget);
    await tester.tap(find.text('Edit details'));
    await tester.pumpAndSettle();
    expect(find.text('19'), findsOneWidget);
    await tester.tap(find.text('Review details'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Adjust quantity'));
    await tester.pumpAndSettle();
    expect(submissions, 1);
    expect(find.text('Open task'), findsOneWidget);
  });

  testWidgets('step actions use the footer and Back preserves entered values',
      (tester) async {
    final quantity = TextEditingController();
    final customer = TextEditingController();
    var step = 0;
    await openForm(
        tester,
        () => TaskForm(
              title: 'Record sale',
              submitLabel: 'Record sale',
              controllers: [quantity, customer],
              shouldAdvance: () => step == 0,
              advanceLabel: () => 'Continue to customer and payment',
              onAdvance: () => step = 1,
              canGoBack: () => step > 0,
              onStepBack: (fromReview) {
                if (!fromReview) step = 0;
              },
              builder: (_, __) => TextFormField(
                controller: step == 0 ? quantity : customer,
                decoration: InputDecoration(
                  labelText: step == 0 ? 'Quantity' : 'Customer name',
                ),
              ),
              reviewBuilder: () => ReviewDetails(
                values: {'Quantity': quantity.text, 'Customer': customer.text},
              ),
              onSubmit: () async => const ActionOutcome.success(),
            ));

    expect(
      find.widgetWithText(FilledButton, 'Continue to customer and payment'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField), '4');
    await tester.tap(find.text('Continue to customer and payment'));
    await tester.pumpAndSettle();
    expect(find.text('Customer name'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Back'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Maria Santos');
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Quantity'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('Continue to customer and payment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Maria Santos');
    await tester.tap(find.text('Review details'));
    await tester.pumpAndSettle();
    expect(find.text('Review before saving'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Customer name'), findsOneWidget);
    expect(find.text('Maria Santos'), findsOneWidget);
  });

  testWidgets('back and cancel require explicit discard for dirty forms',
      (tester) async {
    await openForm(tester, () {
      final controller = TextEditingController();
      return TaskForm(
          title: 'Edit profile',
          submitLabel: 'Save',
          controllers: [controller],
          builder: (_, __) => TextFormField(controller: controller),
          onSubmit: () async => const ActionOutcome.success());
    });
    await tester.enterText(find.byType(TextFormField), 'Maria');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Maria'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('Open task'), findsOneWidget);
  });

  testWidgets('uncertain writes cannot be replayed from the form',
      (tester) async {
    var submissions = 0;
    await openForm(
        tester,
        () => TaskForm(
            title: 'Sale',
            submitLabel: 'Record sale',
            builder: (_, __) => const Text('12 kg'),
            onSubmit: () async {
              submissions++;
              return const ActionOutcome.unknown('Check transactions.');
            }));
    await tester.tap(find.text('Record sale'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(submissions, 1);
    expect(find.text('Check transactions.'), findsOneWidget);
  });

  testWidgets(
      'selector searches options and preserves selection on cancellation',
      (tester) async {
    String? selected = 'Option 1';
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AppSelector<String>(
                value: selected,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  for (var i = 0; i < 10; i++)
                    DropdownMenuItem(
                        value: 'Option $i', child: Text('Option $i'))
                ],
                onChanged: (value) => selected = value))));
    await tester.tap(find.text('Option 1'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Option 9'));
    await tester.pumpAndSettle();
    expect(selected, 'Option 9');
    await tester.tap(find.text('Option 9'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(selected, 'Option 9');
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('form and review fit 320px, scale $scale, dark $dark',
          (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
            theme: dark ? AppTheme.dark : AppTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: TaskForm(
                title: 'Record sale',
                submitLabel: 'Record sale',
                builder: (_, __) =>
                    const Text('Available: 1,234,567,890.25 kg'),
                reviewBuilder: () => const ReviewDetails(values: {
                      'Total': 'PHP 1,234,567,890.25',
                      'Item': 'Long inventory item name with field location'
                    }),
                onSubmit: () async => const ActionOutcome.success())));
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Review details'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('failed destructive confirmation remains open', (tester) async {
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showActionConfirmation(context,
                        title: 'Delete item?',
                        message: 'Delete Sitaw?',
                        actionLabel: 'Delete item',
                        destructive: true,
                        onConfirm: () async => const ActionOutcome.failure(
                            'This item has transactions.')),
                    child: const Text('Delete'))))));
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete item'));
    await tester.pumpAndSettle();
    expect(find.text('This item has transactions.'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
