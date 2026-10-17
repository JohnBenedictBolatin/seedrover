import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_environment.dart';
import '../services/push_notification_service.dart';

class AppBootstrap {
  const AppBootstrap._();

  static Future<AppEnvironment> initialize() async {
    final environment = AppEnvironment.fromDartDefines();

    try {
      await Supabase.initialize(
        url: environment.supabaseUrl,
        anonKey: environment.supabaseAnonKey,
      );
      await PushNotificationService.instance.initialize(Supabase.instance.client);
    } catch (error, stackTrace) {
      debugPrint('AppBootstrap initialization warning: $error\n$stackTrace');
    }

    return environment;
  }
}
