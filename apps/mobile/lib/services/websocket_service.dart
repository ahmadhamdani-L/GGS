import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/config.dart';
import '../models/ws_message.dart';
import 'debug_logger.dart';

/// Connection status enum
enum WsConnectionStatus { disconnected, connecting, connected, reconnecting }

/// WebSocket service for realtime game communication with Go backend
class WebSocketService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<WsMessage>.broadcast();
  final _statusController = StreamController<WsConnectionStatus>.broadcast();
  // Emits a single event when this session is kicked by a new login on another device
  final _sessionReplacedController = StreamController<String>.broadcast();
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  Timer? _connectionTimeout;
  bool _isConnected = false;
  bool _sessionReplaced = false; // Guard: do not reconnect after being evicted
  String? _token;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _connectTimeout = Duration(seconds: 10);

  bool get isConnected => _isConnected;
  Stream<WsMessage> get messages => _messageController.stream;
  Stream<WsConnectionStatus> get statusStream => _statusController.stream;
  /// Emits a message string when this session is replaced by a new login on another device
  Stream<String> get sessionReplacedStream => _sessionReplacedController.stream;
  WsConnectionStatus _status = WsConnectionStatus.disconnected;
  WsConnectionStatus get status => _status;

  void _setStatus(WsConnectionStatus s) {
    _status = s;
    _statusController.add(s);
    logger.debug(LogCategory.ws, 'Status: ${s.name}');
  }

  Future<void> connect(String token) async {
    _token = token;
    _setStatus(WsConnectionStatus.connecting);
    
    final wsUrl = '${AppConfig.wsUrl}?token=$token';
    logger.wsConnecting(wsUrl);

    // Set connection timeout
    _connectionTimeout?.cancel();
    _connectionTimeout = Timer(_connectTimeout, () {
      if (!_isConnected) {
        logger.wsError('Connection timeout after ${_connectTimeout.inSeconds}s');
        _handleConnectionFailure('Connection timeout');
      }
    });

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      await _channel!.ready;
      _connectionTimeout?.cancel();
      _isConnected = true;
      _reconnectAttempts = 0;
      _setStatus(WsConnectionStatus.connected);
      logger.wsConnected();

      _channel!.stream.listen(
        (data) {
          try {
            final message = WsMessage.fromJson(data as String);
            logger.wsReceive(message.type, message.payload);
            // Detect session_replaced before forwarding to other listeners
            if (message.type == 'session_replaced') {
              _sessionReplaced = true;
              final msg = message.payload['message'] as String? ?? 'Sesi digantikan oleh login baru.';
              _sessionReplacedController.add(msg);
              // Disconnect cleanly — do not reconnect
              disconnect();
              return;
            }
            _messageController.add(message);
          } catch (e, stack) {
            logger.wsError('Failed to parse message: $data', stack: stack);
          }
        },
        onError: (e, stack) {
          logger.wsError('Stream error: $e', stack: stack);
          _handleConnectionFailure('Stream error: $e');
        },
        onDone: () {
          logger.wsDisconnected('Stream closed');
          _handleConnectionFailure('Connection closed');
        },
      );

      _startPing();
    } catch (e, stack) {
      _connectionTimeout?.cancel();
      logger.wsError('Connection failed: $e', stack: stack);
      _handleConnectionFailure('Connection failed: $e');
    }
  }

  void _handleConnectionFailure(String reason) {
    _isConnected = false;
    _setStatus(WsConnectionStatus.disconnected);
    _scheduleReconnect();
  }

  void send(WsMessage message) {
    if (!_isConnected || _channel == null) {
      logger.warn(LogCategory.ws, 'Cannot send - not connected', {'type': message.type});
      return;
    }
    logger.wsSend(message.type, message.payload);
    _channel!.sink.add(message.toJson());
  }

  Future<void> disconnect() async {
    logger.info(LogCategory.ws, 'Disconnecting');
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _connectionTimeout?.cancel();
    _isConnected = false;
    _setStatus(WsConnectionStatus.disconnected);
    await _channel?.sink.close();
    _channel = null;
  }

  void _scheduleReconnect() {
    // Never reconnect after session was replaced by a new device login
    if (_sessionReplaced) return;
    if (_token == null || _reconnectAttempts >= _maxReconnectAttempts) {
      if (_reconnectAttempts >= _maxReconnectAttempts) {
        logger.error(LogCategory.ws, 'Max reconnect attempts reached', 
          data: {'attempts': _reconnectAttempts});
      }
      return;
    }
    _reconnectAttempts++;
    _setStatus(WsConnectionStatus.reconnecting);
    logger.wsReconnecting(_reconnectAttempts, _maxReconnectAttempts);

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s
    final delay = Duration(seconds: 1 << (_reconnectAttempts - 1));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (_token != null && !_isConnected) {
        try {
          await _channel?.sink.close();
          _channel = null;
          await connect(_token!);
        } catch (e) {
          logger.wsError('Reconnect failed: $e');
        }
      }
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) send(WsMessage.ping());
    });
  }

  void dispose() {
    logger.debug(LogCategory.ws, 'Disposing WebSocket service');
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _connectionTimeout?.cancel();
    _messageController.close();
    _statusController.close();
    _sessionReplacedController.close();
    _channel?.sink.close();
  }
}
