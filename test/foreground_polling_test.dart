import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/core/services/foreground_polling.dart';

void main() {
  testWidgets('checks every 120 seconds only in the foreground',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var calls = 0;
    final polling = ForegroundPolling(
      interval: const Duration(seconds: 120),
      check: () async {
        calls++;
      },
    )..start();
    await tester.pump();
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 119));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 10));
    await polling.requestCheck();
    expect(calls, 2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 3);
    // A reconnect event immediately after resume must not duplicate the check.
    await polling.requestCheck();
    expect(calls, 3);
    await tester.pump(const Duration(seconds: 120));
    expect(calls, 4);
    polling.dispose();
    await tester.pump(const Duration(minutes: 10));
    expect(calls, 4);
  });

  testWidgets('slow checks never overlap or reschedule after disposal',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final pending = Completer<void>();
    var calls = 0;
    final polling = ForegroundPolling(
      interval: const Duration(seconds: 120),
      check: () {
        calls++;
        return pending.future;
      },
    )..start();
    await tester.pump(const Duration(minutes: 3));
    await polling.requestCheck();
    expect(calls, 1);
    polling.dispose();
    pending.complete();
    await tester.pump(const Duration(minutes: 5));
    expect(calls, 1);
  });

  testWidgets('starting in the background waits for resume', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    var calls = 0;
    final polling = ForegroundPolling(
      interval: const Duration(seconds: 120),
      check: () async {
        calls++;
      },
    )..start();
    await tester.pump(const Duration(minutes: 5));
    expect(calls, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(calls, 1);
    polling.dispose();
  });
}
