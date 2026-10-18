import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_bootstrap.dart';
import 'core/config/app_environment.dart';
import 'core/config/seedrover_app.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_typography.dart';
import 'shared/widgets/primary_button.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapGate());
}

class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate();

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  AppEnvironment? _environment;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    setState(() => _loading = true);
    try {
      final environment = await AppBootstrap.initialize();
      if (!mounted) return;
      setState(() {
        _environment = environment;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final environment = _environment;
    if (environment != null) {
      return ProviderScope(
        overrides: [appEnvironmentProvider.overrideWithValue(environment)],
        child: const SeedRoverApp(),
      );
    }

    return MaterialApp(
      title: 'SeedRover',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_loading)
                    CircularProgressIndicator(color: AppColors.primaryGreen)
                  else
                    Icon(Icons.cloud_off_rounded,
                        size: 36, color: AppColors.warning),
                  const SizedBox(height: 16),
                  Text(
                    _loading
                        ? 'Starting SeedRover…'
                        : 'SeedRover could not start. Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body,
                  ),
                  if (!_loading) ...[
                    const SizedBox(height: 16),
                    PrimaryButton(label: 'Try again', onPressed: _initialize),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
