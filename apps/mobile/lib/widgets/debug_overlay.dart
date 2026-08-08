import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/debug_logger.dart';

/// Debug overlay that shows live logs in the app
/// Only visible in debug mode
class DebugOverlay extends StatefulWidget {
  final Widget child;
  
  const DebugOverlay({super.key, required this.child});

  @override
  State<DebugOverlay> createState() => _DebugOverlayState();
}

class _DebugOverlayState extends State<DebugOverlay> {
  bool _isVisible = false;
  bool _isExpanded = false;
  LogCategory? _filterCategory;
  LogLevel _filterLevel = LogLevel.debug;
  final List<LogEntry> _visibleLogs = [];
  StreamSubscription? _logSubscription;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _visibleLogs.addAll(logger.logs.reversed.take(50));
      _logSubscription = logger.logStream.listen((entry) {
        if (mounted) {
          setState(() {
            _visibleLogs.insert(0, entry);
            if (_visibleLogs.length > 100) {
              _visibleLogs.removeLast();
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _logSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  List<LogEntry> get _filteredLogs {
    return _visibleLogs.where((log) {
      if (_filterCategory != null && log.category != _filterCategory) {
        return false;
      }
      if (log.level.index < _filterLevel.index) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;

    return Stack(
      children: [
        widget.child,
        // Toggle button
        Positioned(
          right: 8,
          bottom: MediaQuery.of(context).padding.bottom + 80,
          child: GestureDetector(
            onTap: () => setState(() => _isVisible = !_isVisible),
            onLongPress: () => setState(() {
              _isVisible = true;
              _isExpanded = !_isExpanded;
            }),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hasErrors 
                    ? Colors.red.withValues(alpha: 0.9)
                    : Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(
                _isVisible ? Icons.close : Icons.bug_report,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
        // Log panel
        if (_isVisible)
          Positioned(
            left: 8,
            right: 8,
            bottom: MediaQuery.of(context).padding.bottom + 130,
            child: _buildLogPanel(),
          ),
      ],
    );
  }

  bool get _hasErrors {
    return _visibleLogs.any((l) => l.level == LogLevel.error);
  }

  Widget _buildLogPanel() {
    final height = _isExpanded ? 400.0 : 200.0;
    
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),
          // Filters
          _buildFilters(),
          // Logs
          Expanded(
            child: _buildLogList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.terminal, color: Colors.greenAccent, size: 16),
          const SizedBox(width: 8),
          const Text(
            'Debug Logs',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          // Error count badge
          if (_hasErrors)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_visibleLogs.where((l) => l.level == LogLevel.error).length}',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          const SizedBox(width: 8),
          // Clear button
          GestureDetector(
            onTap: () {
              logger.clear();
              setState(() => _visibleLogs.clear());
            },
            child: const Icon(Icons.delete_outline, color: Colors.white54, size: 18),
          ),
          const SizedBox(width: 8),
          // Expand button
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Icon(
              _isExpanded ? Icons.unfold_less : Icons.unfold_more,
              color: Colors.white54,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Row(
        children: [
          // Category filter
          _buildFilterChip('All', _filterCategory == null, () {
            setState(() => _filterCategory = null);
          }),
          _buildFilterChip('WS', _filterCategory == LogCategory.ws, () {
            setState(() => _filterCategory = _filterCategory == LogCategory.ws ? null : LogCategory.ws);
          }),
          _buildFilterChip('Room', _filterCategory == LogCategory.room, () {
            setState(() => _filterCategory = _filterCategory == LogCategory.room ? null : LogCategory.room);
          }),
          _buildFilterChip('Game', _filterCategory == LogCategory.game, () {
            setState(() => _filterCategory = _filterCategory == LogCategory.game ? null : LogCategory.game);
          }),
          _buildFilterChip('API', _filterCategory == LogCategory.api, () {
            setState(() => _filterCategory = _filterCategory == LogCategory.api ? null : LogCategory.api);
          }),
          const Spacer(),
          // Level filter
          _buildLevelChip(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.blue : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.blue : Colors.white54,
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildLevelChip() {
    return GestureDetector(
      onTap: () {
        setState(() {
          // Cycle through levels
          final levels = LogLevel.values;
          final currentIndex = levels.indexOf(_filterLevel);
          _filterLevel = levels[(currentIndex + 1) % levels.length];
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: _getLevelColor(_filterLevel).withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _getLevelColor(_filterLevel)),
        ),
        child: Text(
          '≥${_filterLevel.name.toUpperCase()}',
          style: TextStyle(
            color: _getLevelColor(_filterLevel),
            fontSize: 10,
          ),
        ),
      ),
    );
  }

  Widget _buildLogList() {
    final logs = _filteredLogs;
    
    if (logs.isEmpty) {
      return const Center(
        child: Text(
          'No logs',
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        return _buildLogEntry(logs[index]);
      },
    );
  }

  Widget _buildLogEntry(LogEntry entry) {
    final color = _getLevelColor(entry.level);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            _formatTime(entry.timestamp),
            style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace'),
          ),
          const SizedBox(width: 4),
          // Level indicator
          Container(
            width: 4,
            height: 12,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 4),
          // Category
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.category.name.toUpperCase(),
              style: const TextStyle(color: Colors.white54, fontSize: 8, fontFamily: 'monospace'),
            ),
          ),
          const SizedBox(width: 6),
          // Message
          Expanded(
            child: Text(
              entry.message + (entry.error != null ? ' [${entry.error}]' : ''),
              style: TextStyle(
                color: entry.level == LogLevel.error ? Colors.redAccent : Colors.white70,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
           '${dt.minute.toString().padLeft(2, '0')}:'
           '${dt.second.toString().padLeft(2, '0')}';
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.debug: return Colors.cyan;
      case LogLevel.info: return Colors.green;
      case LogLevel.warn: return Colors.orange;
      case LogLevel.error: return Colors.red;
    }
  }
}

/// Wrap your MaterialApp with this to enable debug overlay
class DebugOverlayWrapper extends StatelessWidget {
  final Widget child;
  
  const DebugOverlayWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return child;
    return DebugOverlay(child: child);
  }
}
