import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();
  Future<void> initialize(SupabaseClient client) async {
    // Push notifications are not configured for this Supabase-only app.
  }

  Future<String?> consumePendingDeepLink() async {
    return null;
  }

  Future<void> dispose() async {
  }
}
