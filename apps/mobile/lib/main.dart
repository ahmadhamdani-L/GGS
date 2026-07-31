import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'widgets/debug_overlay.dart';
import 'services/debug_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logger
  logger.info(LogCategory.system, 'App starting');

  runApp(
    const ProviderScope(
      child: GGSApp(),
    ),
  );
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
        // Wrap with debug overlay in debug mode
        return DebugOverlayWrapper(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
