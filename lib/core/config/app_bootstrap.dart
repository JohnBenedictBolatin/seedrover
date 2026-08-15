import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_environment.dart';
import '../services/push_notification_service.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<AppEnvironment> initialize() async {
    await dotenv.load(fileName: '.env');

    final environment = AppEnvironment.fromDotEnv(dotenv.env);

    await Supabase.initialize(
      url: environment.supabaseUrl,
      anonKey: environment.supabaseAnonKey,
    );
    await PushNotificationService.instance.initialize(Supabase.instance.client);

    return environment;
  }
}
