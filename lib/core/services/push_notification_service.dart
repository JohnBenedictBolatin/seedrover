import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationService {
  PushNotificationService._();

  static final instance = PushNotificationService._();

  static const _permissionRequestedKey = 'push_permission_requested';
  static const _channelId = 'seedrover_alerts';
  static const _channelName = 'SeedRover alerts';
  static const _androidChannel = MethodChannel('seedrover/push');
  static const _tokenRefreshChannel = EventChannel('seedrover/push/tokenRefresh');
  static const _foregroundMessageChannel =
      EventChannel('seedrover/push/foregroundMessages');
  static const _notificationTapChannel = EventChannel('seedrover/push/taps');

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  SupabaseClient? _client;
  StreamSubscription<dynamic>? _tokenSubscription;
  StreamSubscription<dynamic>? _foregroundSubscription;
  StreamSubscription<dynamic>? _tapSubscription;
  String? _activeProfileId;
  String? _currentToken;
  String? _pendingDeepLink;
  bool _isAuthenticated = false;
  void Function(String route)? _navigateToRoute;
  bool _initialized = false;
  bool _androidPushReady = false;
  bool _localNotificationsReady = false;
  bool _pushAuthorized = false;

  Future<void> initialize(SupabaseClient client) async {
    if (_initialized) return;
    _initialized = true;
    _client = client;

    if (kIsWeb || !Platform.isAndroid) return;
    _androidPushReady = true;

    try {
      await _initializeLocalNotifications();
    } catch (error) {
      debugPrint('Unable to initialize local notifications: $error');
    }

    _tokenSubscription = _tokenRefreshChannel.receiveBroadcastStream().listen(
      _handleTokenRefresh,
      onError: (Object error) =>
          debugPrint('Unable to listen for push token updates: $error'),
    );
    _foregroundSubscription =
        _foregroundMessageChannel.receiveBroadcastStream().listen(
      _showForegroundNotification,
      onError: (Object error) =>
          debugPrint('Unable to receive foreground push alerts: $error'),
    );
    _tapSubscription = _notificationTapChannel.receiveBroadcastStream().listen(
      (value) => _acceptDeepLink(value?.toString()),
      onError: (Object error) =>
          debugPrint('Unable to receive notification taps: $error'),
    );

    try {
      final route = await _androidChannel.invokeMethod<String>(
        'consumePendingRoute',
      );
      _acceptDeepLink(route);
    } on PlatformException catch (error) {
      debugPrint('Unable to read the launch push notification: ${error.message}');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        _acceptDeepLink(response.payload);
      },
    );

    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _acceptDeepLink(launchDetails?.notificationResponse?.payload);
    }

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Updates for your SeedRover farm.',
        importance: Importance.high,
      ),
    );
    _localNotificationsReady = true;
  }

  /// Ask for Android notification permission on the first signed-in session
  /// and associate the resulting FCM token with that user's Supabase profile.
  Future<void> setAuthenticatedUser(String? profileId) async {
    if (!_androidPushReady) return;

    final nextProfileId = profileId?.trim();
    if (nextProfileId == _activeProfileId) return;

    if (nextProfileId == null || nextProfileId.isEmpty) {
      _isAuthenticated = false;
      _pushAuthorized = false;
      await _deactivateCurrentToken();
      _activeProfileId = null;
      return;
    }

    _activeProfileId = nextProfileId;
    _isAuthenticated = true;

    try {
      final preferences = await SharedPreferences.getInstance();
      final hasRequestedPermission =
          preferences.getBool(_permissionRequestedKey) == true;
      if (!hasRequestedPermission) {
        await preferences.setBool(_permissionRequestedKey, true);
      }
      _pushAuthorized = await _androidChannel.invokeMethod<bool>(
            'requestNotificationPermission',
            {'requestIfDenied': !hasRequestedPermission},
          ) ??
          false;
    } catch (error) {
      debugPrint('Unable to request SeedRover notification permission: $error');
      return;
    }

    if (!_pushAuthorized) {
      await _deactivateCurrentToken();
      return;
    }

    await _loadAndRegisterToken();
  }

  void setNavigationHandler({
    required bool isAuthenticated,
    required void Function(String route) onNavigate,
  }) {
    _isAuthenticated = isAuthenticated;
    _navigateToRoute = onNavigate;
    _dispatchPendingDeepLink();
  }

  Future<void> _loadAndRegisterToken() async {
    try {
      _currentToken = await _androidChannel.invokeMethod<String>('getPushToken');
    } on PlatformException catch (error) {
      debugPrint('Unable to get the SeedRover push token: ${error.message}');
    }

    final token = _currentToken;
    if (token != null && token.isNotEmpty) await _registerToken(token);
  }

  void _handleTokenRefresh(dynamic value) {
    if (value is! String || value.isEmpty) return;
    _currentToken = value;
    if (_activeProfileId != null && _pushAuthorized) {
      unawaited(_registerToken(value));
    }
  }

  Future<void> _registerToken(String token) async {
    final client = _client;
    if (client == null || _activeProfileId == null || !_androidPushReady) return;

    try {
      await client.rpc('register_push_device_token', params: {
        'p_token': token,
        'p_platform': 'android',
      });
    } catch (error) {
      debugPrint('Unable to register the SeedRover push token: $error');
    }
  }

  Future<void> _deactivateCurrentToken() async {
    final token = _currentToken;
    final client = _client;
    if (token == null || token.isEmpty || client == null) return;

    try {
      await client.rpc(
        'deactivate_push_device_token',
        params: {'p_token': token},
      );
    } catch (error) {
      debugPrint('Unable to deactivate the SeedRover push token: $error');
    }
  }

  Future<void> _showForegroundNotification(dynamic event) async {
    if (!_localNotificationsReady || event is! Map) return;
    final data = <String, dynamic>{
      for (final entry in event.entries) entry.key.toString(): entry.value,
    };
    final title = data['title']?.toString();
    final body = data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    final route = _routeFromData(data);
    final notificationId = data['notification_id']?.toString() ?? '';
    final localId = notificationId.hashCode & 0x7fffffff;
    await _localNotifications.show(
      localId,
      title ?? 'SeedRover',
      body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Updates for your SeedRover farm.',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: jsonEncode({'route': route}),
    );
  }

  String _routeFromData(Map<String, dynamic> data) {
    final value = data['route'] ?? data['deep_link'];
    return _sanitizeRoute(value?.toString()) ?? '/notifications';
  }

  void _acceptDeepLink(String? value) {
    var route = _sanitizeRoute(value);
    if (route == null && value != null) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) route = _sanitizeRoute(decoded['route']?.toString());
      } catch (_) {
        // The payload may be a direct path from an older notification.
      }
    }
    if (route != null) {
      _pendingDeepLink = route;
      _dispatchPendingDeepLink();
    }
  }

  void _dispatchPendingDeepLink() {
    final route = _pendingDeepLink;
    final navigate = _navigateToRoute;
    if (!_isAuthenticated || route == null || navigate == null) return;

    _pendingDeepLink = null;
    Timer.run(() => navigate(route));
  }

  String? _sanitizeRoute(String? value) {
    final raw = value?.trim();
    if (raw == null ||
        raw.isEmpty ||
        !raw.startsWith('/') ||
        raw.startsWith('//')) {
      return null;
    }

    final uri = Uri.tryParse(raw);
    if (uri == null || uri.hasAuthority || uri.hasFragment) return null;
    final path = uri.path;
    if (path == '/crops') {
      final cropId = uri.queryParameters['crop'];
      final taskId = uri.queryParameters['task'];
      final uuidPattern = RegExp(r'^[0-9a-fA-F-]{36}$');
      if (cropId != null && uuidPattern.hasMatch(cropId)) {
        final detailsRoute = '/crops/$cropId';
        return taskId != null && uuidPattern.hasMatch(taskId)
            ? '$detailsRoute?task=${Uri.encodeComponent(taskId)}'
            : detailsRoute;
      }
    }
    if (path == '/inventory') return '/stocks';
    if (path == '/rover-monitor') return '/rover';
    if (path == '/users' || path.startsWith('/users/')) return '/profile';

    const fixedRoutes = {
      '/dashboard',
      '/rover',
      '/crops',
      '/stocks',
      '/notifications',
      '/profile',
    };
    if (fixedRoutes.contains(path)) {
      return uri.hasQuery ? '$path?${uri.query}' : path;
    }

    final detailPatterns = [
      RegExp(r'^/crops/[0-9a-fA-F-]{36}$'),
      RegExp(r'^/stocks/[0-9a-fA-F-]{36}$'),
      RegExp(r'^/notifications/[0-9a-fA-F-]{36}$'),
      RegExp(r'^/planting-logs/[0-9a-fA-F-]{36}$'),
    ];
    if (detailPatterns.any((pattern) => pattern.hasMatch(path))) {
      return uri.hasQuery ? '$path?${uri.query}' : path;
    }
    return null;
  }

  Future<void> dispose() async {
    await _tokenSubscription?.cancel();
    await _foregroundSubscription?.cancel();
    await _tapSubscription?.cancel();
  }
}
