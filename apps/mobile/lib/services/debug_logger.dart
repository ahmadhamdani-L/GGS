import 'dart:async';
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Log levels for filtering
enum LogLevel { debug, info, warn, error }

/// Log categories for grouping
enum LogCategory { 
  api,      // HTTP requests/responses
  ws,       // WebSocket events
  auth,     // Authentication
  room,     // Room operations
  game,     // Game state changes
  ui,       // UI events
  provider, // Provider state changes
  system,   // System events
}

/// A single log entry
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final Map<String, dynamic>? data;
  final String? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.data,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'level': level.name.toUpperCase(),
    'category': category.name.toUpperCase(),
    'message': message,
    if (data != null) 'data': data,
    if (error != null) 'error': error,
  };

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${_formatTime(timestamp)}] ');
    buffer.write('[${level.name.toUpperCase().padRight(5)}] ');
    buffer.write('[${category.name.toUpperCase().padRight(8)}] ');
    buffer.write(message);
    if (data != null && data!.isNotEmpty) {
      buffer.write(' ${jsonEncode(data)}');
    }
    if (error != null) {
      buffer.write(' ERROR: $error');
    }
    return buffer.toString();
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
           '${dt.minute.toString().padLeft(2, '0')}:'
           '${dt.second.toString().padLeft(2, '0')}.'
           '${dt.millisecond.toString().padLeft(3, '0')}';
  }

  /// Color for console output
  String get levelColor {
    switch (level) {
      case LogLevel.debug: return '\x1B[36m'; // Cyan
      case LogLevel.info: return '\x1B[32m';  // Green
      case LogLevel.warn: return '\x1B[33m';  // Yellow
      case LogLevel.error: return '\x1B[31m'; // Red
    }
  }

  String toColoredString() {
    const reset = '\x1B[0m';
    return '$levelColor${toString()}$reset';
  }
}

/// Debug logger service - singleton
class DebugLogger {
  static final DebugLogger _instance = DebugLogger._internal();
  factory DebugLogger() => _instance;
  DebugLogger._internal();

  /// Maximum logs to keep in memory
  static const int maxLogs = 500;

  /// Minimum level to log (can be changed at runtime)
  LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Whether to print to console
  bool printToConsole = false;

  /// Whether to write to file (always enabled)
  bool writeToFile = true;

  /// File log path — written to app's documents directory
  /// On iOS simulator: ~/Library/Developer/CoreSimulator/Devices/.../Documents/ggs_debug.log
  /// On real device: accessible via Files app or Xcode device logs
  IOSink? _fileSink;
  String? logFilePath;

  /// Initialize file logging — call once at app start
  Future<void> initFileLogging() async {
    if (!writeToFile) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/ggs_debug.log');
      // Truncate on each app start (keep fresh)
      _fileSink = file.openWrite(mode: FileMode.write);
      logFilePath = file.path;
      _fileSink!.writeln('=== GGS Werewolf Debug Log ===');
      _fileSink!.writeln('Started: ${DateTime.now().toIso8601String()}');
      _fileSink!.writeln('${'=' * 50}\n');
      debugPrint('[LOG] File logging to: ${file.path}');
    } catch (e) {
      debugPrint('[LOG] File logging init failed: $e');
    }
  }

  /// Flush and close the log file
  Future<void> closeFileLog() async {
    await _fileSink?.flush();
    await _fileSink?.close();
    _fileSink = null;
  }

  /// Recent logs (circular buffer)
  final Queue<LogEntry> _logs = Queue<LogEntry>();

  /// Stream controller for live log updates
  final _logController = StreamController<LogEntry>.broadcast();

  /// Stream of new log entries
  Stream<LogEntry> get logStream => _logController.stream;

  /// Get all recent logs
  List<LogEntry> get logs => _logs.toList();

  /// Get logs filtered by category
  List<LogEntry> getByCategory(LogCategory category) {
    return _logs.where((l) => l.category == category).toList();
  }

  /// Get logs filtered by level (and above)
  List<LogEntry> getByLevel(LogLevel minLevel) {
    return _logs.where((l) => l.level.index >= minLevel.index).toList();
  }

  /// Clear all logs
  void clear() {
    _logs.clear();
  }

  /// Core logging method
  void _log(LogLevel level, LogCategory category, String message, {
    Map<String, dynamic>? data,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      category: category,
      message: message,
      data: data,
      error: error?.toString(),
      stackTrace: stackTrace,
    );

    // Add to buffer
    _logs.add(entry);
    while (_logs.length > maxLogs) {
      _logs.removeFirst();
    }

    // Notify listeners
    _logController.add(entry);

    // Print to console if enabled
    if (printToConsole) {
      debugPrint(entry.toColoredString());
      if (stackTrace != null && level == LogLevel.error) {
        debugPrint(stackTrace.toString());
      }
    }

    // Write to file if enabled
    if (writeToFile && _fileSink != null) {
      _fileSink!.writeln(entry.toColoredString());
      if (stackTrace != null && level == LogLevel.error) {
        _fileSink!.writeln(stackTrace.toString());
      }
    }
  }

  // Convenience methods by level
  void debug(LogCategory cat, String msg, [Map<String, dynamic>? data]) {
    _log(LogLevel.debug, cat, msg, data: data);
  }

  void info(LogCategory cat, String msg, [Map<String, dynamic>? data]) {
    _log(LogLevel.info, cat, msg, data: data);
  }

  void warn(LogCategory cat, String msg, [Map<String, dynamic>? data]) {
    _log(LogLevel.warn, cat, msg, data: data);
  }

  void error(LogCategory cat, String msg, {Object? error, StackTrace? stack, Map<String, dynamic>? data}) {
    _log(LogLevel.error, cat, msg, data: data, error: error, stackTrace: stack);
  }

  // ─── API Logging ─────────────────────────────────────────

  void apiRequest(String method, String path, {Map<String, dynamic>? body}) {
    debug(LogCategory.api, '$method $path', body != null ? {'body': body} : null);
  }

  void apiResponse(String method, String path, int status, Duration duration, {dynamic body}) {
    final level = status >= 400 ? LogLevel.error : (status >= 300 ? LogLevel.warn : LogLevel.info);
    _log(level, LogCategory.api, '$method $path → $status (${duration.inMilliseconds}ms)', 
      data: body != null ? {'response': body} : null);
  }

  void apiError(String method, String path, String error, {int? status}) {
    this.error(LogCategory.api, '$method $path failed', 
      error: error, 
      data: status != null ? {'status': status} : null);
  }

  // ─── WebSocket Logging ───────────────────────────────────

  void wsConnecting(String url) {
    info(LogCategory.ws, 'Connecting to WebSocket', {'url': url});
  }

  void wsConnected() {
    info(LogCategory.ws, 'WebSocket connected');
  }

  void wsDisconnected(String reason) {
    warn(LogCategory.ws, 'WebSocket disconnected', {'reason': reason});
  }

  void wsReconnecting(int attempt, int maxAttempts) {
    info(LogCategory.ws, 'WebSocket reconnecting', {
      'attempt': attempt,
      'maxAttempts': maxAttempts,
    });
  }

  void wsSend(String type, [Map<String, dynamic>? payload]) {
    debug(LogCategory.ws, '→ $type', payload);
  }

  void wsReceive(String type, [Map<String, dynamic>? payload]) {
    debug(LogCategory.ws, '← $type', payload);
  }

  void wsError(String error, {StackTrace? stack}) {
    this.error(LogCategory.ws, 'WebSocket error', error: error, stack: stack);
  }

  // ─── Room Logging ────────────────────────────────────────

  void roomCreating(String userId) {
    info(LogCategory.room, 'Creating room', {'userId': userId});
  }

  void roomCreated(String roomId, String code) {
    info(LogCategory.room, 'Room created', {'roomId': roomId, 'code': code});
  }

  void roomJoining(String code) {
    info(LogCategory.room, 'Joining room', {'code': code});
  }

  void roomJoined(String roomId, String code) {
    info(LogCategory.room, 'Joined room', {'roomId': roomId, 'code': code});
  }

  void roomLeft(String roomId, String reason) {
    info(LogCategory.room, 'Left room', {'roomId': roomId, 'reason': reason});
  }

  void roomError(String operation, String error) {
    this.error(LogCategory.room, 'Room $operation failed', error: error);
  }

  void roomPlayerJoined(String playerId, String? name) {
    debug(LogCategory.room, 'Player joined', {'playerId': playerId, 'name': name});
  }

  void roomPlayerLeft(String playerId) {
    debug(LogCategory.room, 'Player left', {'playerId': playerId});
  }

  // ─── Game Logging ────────────────────────────────────────

  void gameStarting(String roomId, int playerCount) {
    info(LogCategory.game, 'Game starting', {'roomId': roomId, 'players': playerCount});
  }

  void gameStarted(String gameId, String myRole) {
    info(LogCategory.game, 'Game started', {'gameId': gameId, 'myRole': myRole});
  }

  void gamePhaseChange(String from, String to, int round) {
    info(LogCategory.game, 'Phase: $from → $to', {'round': round});
  }

  void gameAction(String action, String? targetId) {
    debug(LogCategory.game, 'Action: $action', targetId != null ? {'target': targetId} : null);
  }

  void gameStateUpdate(String phase, int round, int alivePlayers) {
    debug(LogCategory.game, 'State update', {
      'phase': phase,
      'round': round,
      'alive': alivePlayers,
    });
  }

  void gameEnded(String winner, int rounds) {
    info(LogCategory.game, 'Game ended', {'winner': winner, 'rounds': rounds});
  }

  void gameError(String operation, String error) {
    this.error(LogCategory.game, 'Game $operation failed', error: error);
  }

  // ─── Auth Logging ────────────────────────────────────────

  void authLogin(String method) {
    info(LogCategory.auth, 'Login attempt', {'method': method});
  }

  void authSuccess(String userId) {
    info(LogCategory.auth, 'Auth success', {'userId': userId});
  }

  void authFailed(String reason) {
    warn(LogCategory.auth, 'Auth failed', {'reason': reason});
  }

  void authLogout() {
    info(LogCategory.auth, 'Logged out');
  }

  void authTokenRefresh() {
    debug(LogCategory.auth, 'Token refreshed');
  }

  // ─── Provider Logging ────────────────────────────────────

  void providerStateChange(String provider, String description, [Map<String, dynamic>? data]) {
    debug(LogCategory.provider, '$provider: $description', data);
  }

  void providerError(String provider, String error, {StackTrace? stack}) {
    this.error(LogCategory.provider, '$provider error', error: error, stack: stack);
  }

  // ─── UI Logging ──────────────────────────────────────────

  void uiNavigation(String from, String to) {
    debug(LogCategory.ui, 'Navigate: $from → $to');
  }

  void uiAction(String action, [Map<String, dynamic>? data]) {
    debug(LogCategory.ui, 'Action: $action', data);
  }

  // ─── Export ──────────────────────────────────────────────

  /// Export logs as JSON string (for sharing/debugging)
  String exportLogs() {
    return jsonEncode(_logs.map((l) => l.toJson()).toList());
  }

  /// Get summary of recent errors
  List<LogEntry> getRecentErrors({int limit = 20}) {
    return _logs
        .where((l) => l.level == LogLevel.error)
        .toList()
        .reversed
        .take(limit)
        .toList();
  }

  void dispose() {
    _logController.close();
  }
}

/// Global logger instance
final logger = DebugLogger();
