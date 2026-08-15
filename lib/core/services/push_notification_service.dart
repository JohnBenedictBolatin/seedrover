import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();
  static const pendingDeepLinkKey = 'pending_notification_deep_link';
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;

  Future<void> initialize(SupabaseClient client) async {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase native configuration is supplied per deployment.
      return;
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    _authSubscription = client.auth.onAuthStateChange
        .listen((_) => _registerCurrentToken(client, messaging));
    _tokenSubscription =
        messaging.onTokenRefresh.listen((token) => _upsertToken(client, token));
    _openedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_rememberDeepLink);
    final initial = await messaging.getInitialMessage();
    if (initial != null) await _rememberDeepLink(initial);
    await _registerCurrentToken(client, messaging);
  }

  Future<void> _registerCurrentToken(
      SupabaseClient client, FirebaseMessaging messaging) async {
    if (client.auth.currentUser == null) return;
    final token = await messaging.getToken();
    if (token != null) await _upsertToken(client, token);
  }

  Future<void> _upsertToken(SupabaseClient client, String token) async {
    final user = client.auth.currentUser;
    if (user == null) return;
    await client.rpc('register_push_device_token', params: {
      'p_token': token,
      'p_platform': Platform.isIOS ? 'ios' : 'android',
    });
  }

  Future<void> _rememberDeepLink(RemoteMessage message) async {
    final link = message.data['deep_link']?.toString();
    if (link == null || !link.startsWith('/')) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(pendingDeepLinkKey, link);
  }

  Future<String?> consumePendingDeepLink() async {
    final preferences = await SharedPreferences.getInstance();
    final link = preferences.getString(pendingDeepLinkKey);
    if (link != null) await preferences.remove(pendingDeepLinkKey);
    return link;
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
    await _openedSubscription?.cancel();
  }
}
