import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'services/debug_logger.dart';
import 'services/push_notification_service.dart';

/// Background message handler — must be top-level function
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  logger.info(LogCategory.system, 'Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logger.info(LogCategory.system, 'App starting');

  // Initialize file logging — writes to Documents/ggs_debug.log
  await logger.initFileLogging();
  logger.info(LogCategory.system, 'Log file: ${logger.logFilePath ?? "disabled"}');

  // ─── Firebase ──────────────────────────────────────────────────────────
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ─── Sentry (disabled until SENTRY_DSN is provided) ────────────────────
  // To enable: flutter run --dart-define=SENTRY_DSN=https://your-dsn@sentry.io/123

  runApp(const ProviderScope(child: GGSApp()));
}

class GGSApp extends ConsumerStatefulWidget {
  const GGSApp({super.key});

  @override
  ConsumerState<GGSApp> createState() => _GGSAppState();
}

class _GGSAppState extends ConsumerState<GGSApp> {
  @override
  void initState() {
    super.initState();
    // Initialize push notifications after first frame (needs ref)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pushNotificationServiceProvider).initialize();
    });

    // Watch auth state to register/unregister FCM token
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.listenManual(authProvider, (prev, next) {
        if (prev?.isAuthenticated != true && next.isAuthenticated) {
          // Just logged in — register FCM token
          ref.read(pushNotificationServiceProvider).initialize();
        } else if (prev?.isAuthenticated == true && !next.isAuthenticated) {
          // Logged out — unregister FCM token
          ref.read(pushNotificationServiceProvider).unregister();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'GGS Werewolf',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
