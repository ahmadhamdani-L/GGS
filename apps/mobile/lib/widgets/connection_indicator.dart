import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/room_provider.dart';
import '../services/websocket_service.dart';

/// Shows a banner when WebSocket connection is lost/reconnecting
class ConnectionIndicator extends ConsumerStatefulWidget {
  const ConnectionIndicator({super.key});

  @override
  ConsumerState<ConnectionIndicator> createState() => _ConnectionIndicatorState();
}

class _ConnectionIndicatorState extends ConsumerState<ConnectionIndicator> {
  WsConnectionStatus _status = WsConnectionStatus.connected;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    final ws = ref.read(webSocketProvider);
    _status = ws.status;
    _sub = ws.statusStream.listen((s) {
      if (mounted) setState(() => _status = s);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == WsConnectionStatus.connected) return const SizedBox.shrink();

    final (text, color, icon) = switch (_status) {
      WsConnectionStatus.connecting => ('Menghubungkan...', AppColors.warning, Icons.wifi_rounded),
      WsConnectionStatus.reconnecting => ('Menyambung ulang...', AppColors.warning, Icons.sync_rounded),
      WsConnectionStatus.disconnected => ('Terputus', AppColors.error, Icons.wifi_off_rounded),
      _ => ('', AppColors.textMuted, Icons.circle),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: color.withValues(alpha: 0.15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
