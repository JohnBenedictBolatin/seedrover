import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/shared/widgets/initial_loading_skeleton.dart';

void main() {
  testWidgets(
      'shows a spinner over the skeleton and a slow message after 10 seconds',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: InitialLoadingSkeleton(
            skeleton: Center(child: Text('Page placeholder')),
            label: 'Loading your dashboard…',
          ),
        ),
      ),
    );

    expect(find.text('Page placeholder'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Loading your dashboard…'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();

    expect(
      find.text('This is taking longer than usual. Please wait.'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('uses a non-animated progress icon when motion is disabled',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: InitialLoadingSkeleton(
              skeleton: SizedBox.expand(),
              label: 'Loading your account…',
            ),
          ),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.hourglass_top_rounded), findsOneWidget);
  });
}
