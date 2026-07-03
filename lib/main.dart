import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_bootstrap.dart';
import 'core/config/app_environment.dart';
import 'core/config/seedrover_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final environment = await AppBootstrap.initialize();

  runApp(
    ProviderScope(
      overrides: [
        appEnvironmentProvider.overrideWithValue(environment),
      ],
      child: const SeedRoverApp(),
    ),
  );
}
