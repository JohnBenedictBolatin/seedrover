import 'dart:async';

import 'package:flutter/widgets.dart';

/// Serializes checks and stops scheduling when the app leaves the foreground.
class ForegroundPolling with WidgetsBindingObserver {
  ForegroundPolling({required this.check, required this.interval});

  final Future<void> Function() check;
  final Duration interval;
  Timer? _timer;
  bool _active = false;
  bool _foreground = false;
  bool _checking = false;
  Timer? _wakeCooldown;

  void start() {
    if (_active) return;
    _active = true;
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
    unawaited(requestCheck());
  }

  Future<void> requestCheck() async {
    if (!_active || !_foreground || _checking) return;
    _timer?.cancel();
    // Coalesce duplicate platform connectivity/resume notifications.
    if (_wakeCooldown?.isActive ?? false) {
      _schedule();
      return;
    }
    _checking = true;
    _wakeCooldown = Timer(const Duration(seconds: 1), () {});
    try {
      await check();
    } finally {
      _checking = false;
      _schedule();
    }
  }

  void _schedule() {
    _timer?.cancel();
    if (_active && _foreground && !_checking) {
      _timer = Timer(interval, () => unawaited(requestCheck()));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasForeground = _foreground;
    _foreground = state == AppLifecycleState.resumed;
    _timer?.cancel();
    if (_foreground && !wasForeground) unawaited(requestCheck());
  }

  void dispose() {
    _active = false;
    _timer?.cancel();
    _wakeCooldown?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
