import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

/// Global navigator key — set by GGSApp to enable in-app notification banners
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Handles FCM push notification registration and foreground message handling.
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
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _registerToken(token);
      }
    } catch (e) {
      // iOS simulator doesn't support APNS — skip token registration
      debugPrint('[FCM] Token unavailable (simulator?): $e');
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
      // Delay to let app finish initializing before navigating
      Future.delayed(const Duration(milliseconds: 1500), () {
        _handleNotificationTap(initialMessage);
      });
    }

    debugPrint('[FCM] Push notification service initialized');
  }

  Future<void> _registerToken(String token) async {
    try {
      final api = _ref.read(apiServiceProvider);
      if (api.token == null) return; // Not logged in yet
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

    final context = navigatorKey.currentContext;
    if (context != null) {
      _showInAppBanner(context, notification.title ?? '', notification.body ?? '', message.data);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    final data = message.data;
    debugPrint('[FCM] Notification tapped: type=${data['type']}');
    final context = navigatorKey.currentContext;
    if (context != null) {
      _deepLinkFromData(context, data);
    }
  }

  /// Route to appropriate screen based on notification data
  void _deepLinkFromData(BuildContext context, Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'game_invite':
        final roomCode = data['roomCode'] as String?;
        if (roomCode != null && roomCode.isNotEmpty) {
          GoRouter.of(context).push('/lobby/$roomCode');
        }
        break;
      case 'friend_request':
      case 'friend_accepted':
        GoRouter.of(context).push('/friends');
        break;
      case 'gift_received':
        GoRouter.of(context).push('/gift-inbox');
        break;
      case 'achievement_unlocked':
        GoRouter.of(context).push('/achievements');
        break;
      case 'missions_reset':
        GoRouter.of(context).push('/quest');
        break;
      default:
        GoRouter.of(context).push('/notifications');
        break;
    }
  }

  /// Shows a slide-down banner for foreground push notifications
  void _showInAppBanner(BuildContext context, String title, String body, Map<String, dynamic> data) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _PushBanner(
        title: title,
        body: body,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
        onTap: () {
          if (entry.mounted) entry.remove();
          final ctx = navigatorKey.currentContext;
          if (ctx != null) _deepLinkFromData(ctx, data);
        },
      ),
    );
    overlay.insert(entry);
    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  /// Unregister token on logout
  Future<void> unregister() async {
    _initialized = false;
    try {
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
  }
}

final pushNotificationServiceProvider = Provider<PushNotificationService>(
  (ref) => PushNotificationService(ref),
);

// ─── In-App Push Notification Banner ─────────────────────────

class _PushBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _PushBanner({
    required this.title,
    required this.body,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_PushBanner> createState() => _PushBannerState();
}

class _PushBannerState extends State<_PushBanner> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnim = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: widget.onTap,
          onVerticalDragEnd: (details) {
            if (details.primaryVelocity != null && details.primaryVelocity! < -100) {
              widget.onDismiss();
            }
          },
          child: Container(
            margin: EdgeInsets.fromLTRB(12, topPadding + 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDAA520).withOpacity( 0.4)),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity( 0.4), blurRadius: 20, offset: const Offset(0, 6)),
              ],
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: const Color(0xFFDAA520).withOpacity( 0.15),
                  ),
                  child: const Center(child: Text('🐺', style: TextStyle(fontSize: 18))),
                ),
                const SizedBox(width: 12),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.title,
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (widget.body.isNotEmpty)
                        Text(widget.body,
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                // Dismiss X
                GestureDetector(
                  onTap: widget.onDismiss,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, color: Color(0xFF6B7280), size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
