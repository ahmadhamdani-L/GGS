import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

/// Handles FCM push notification registration and foreground message handling.
///
/// SETUP REQUIRED:
/// 1. Add google-services.json to android/app/
/// 2. Add GoogleService-Info.plist to ios/Runner/
/// 3. Run: flutterfire configure (from firebase_cli)
/// 4. Set FCM_SERVER_KEY in backend .env
class PushNotificationService {
  final Ref _ref;
  PushNotificationService(this._ref);

  static bool _initialized = false;

  /// Call once at app start, after Firebase.initializeApp()
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;

    // Request permission (iOS; Android 13+ also needs this)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('[FCM] Notification permission denied');
      return;
    }

    // Get the FCM token and register with backend
    final token = await messaging.getToken();
    if (token != null) {
      await _registerToken(token);
    }

    // Listen for token refresh
    messaging.onTokenRefresh.listen(_registerToken);

    // Handle foreground messages — show in-app banner
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background (opened from notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check if app was launched from a notification
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    debugPrint('[FCM] Push notification service initialized');
  }

  Future<void> _registerToken(String token) async {
    try {
      final api = _ref.read(apiServiceProvider);
      await api.registerFCMToken(
        token: token,
        platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      );
      debugPrint('[FCM] Token registered: ${token.substring(0, 20)}...');
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    debugPrint('[FCM] Foreground message: ${notification.title}');
    // In-app notification is handled by the NotificationBell widget
    // which listens to the WS notification stream.
    // FCM foreground messages are informational only here.
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    debugPrint('[FCM] Notification tapped: type=$type');
    // Deep-link routing based on notification type
    // (handled by GoRouter redirect after app is ready)
  }

  /// Unregister token on logout
  Future<void> unregister() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(ref),
);

// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // No UI interaction possible here — just log
  debugPrint('[FCM Background] ${message.notification?.title}');
}
