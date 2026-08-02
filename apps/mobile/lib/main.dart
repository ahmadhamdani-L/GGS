import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'services/debug_logger.dart';
import 'widgets/debug_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  logger.info(LogCategory.system, 'App starting');

  // Initialize file logging — writes to Documents/ggs_debug.log
  await logger.initFileLogging();
  logger.info(LogCategory.system, 'Log file: ${logger.logFilePath ?? "disabled"}');

  // ─── Firebase (disabled until GoogleService-Info.plist is added) ────────
  // Uncomment below when Firebase project is configured:
  // import 'package:firebase_core/firebase_core.dart';
  // import 'package:firebase_messaging/firebase_messaging.dart';
  // await Firebase.initializeApp();
  // FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // ─── Sentry (disabled until SENTRY_DSN is provided) ────────────────────
  // To enable: flutter run --dart-define=SENTRY_DSN=https://your-dsn@sentry.io/123
  // For now, run app directly without Sentry wrapper to avoid native SDK crash.

  runApp(const ProviderScope(child: GGSApp()));
}

class GGSApp extends ConsumerWidget {
  const GGSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'GGS Werewolf',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        return DebugOverlayWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
