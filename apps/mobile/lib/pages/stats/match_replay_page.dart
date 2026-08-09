import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class MatchReplayPage extends ConsumerStatefulWidget {
  final String matchId;
  const MatchReplayPage({super.key, required this.matchId});

  @override
  ConsumerState<MatchReplayPage> createState() => _MatchReplayPageState();
}

class _MatchReplayPageState extends ConsumerState<MatchReplayPage> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _actions = [];

  @override
  void initState() {
    super.initState();
    _fetchReplay();
  }

  Future<void> _fetchReplay() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final api = ref.read(apiServiceProvider);
    final res = await api.getMatchReplay(widget.matchId);

    if (mounted) {
      if (res.isSuccess && res.data != null) {
        setState(() {
          _actions = res.data!['actions'] as List<dynamic>? ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = res.error ?? 'Gagal memuat replay pertandingan.';
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildActionIcon(String actionType) {
    IconData iconData;
    Color iconColor;

    switch (actionType) {
      case 'vote':
        iconData = Icons.how_to_vote;
        iconColor = Colors.orange;
        break;
      case 'eliminate':
        iconData = Icons.dangerous;
        iconColor = AppColors.error;
        break;
      case 'skill_use':
        iconData = Icons.flash_on;
        iconColor = AppColors.success;
        break;
      case 'chat':
        iconData = Icons.chat;
        iconColor = Colors.blue;
        break;
      default:
        iconData = Icons.info;
        iconColor = Colors.grey;
    }

    return CircleAvatar(
      backgroundColor: iconColor.withValues(alpha: 0.2),
      child: Icon(iconData, color: iconColor, size: 20),
    );
  }

  Widget _buildActionText(Map<String, dynamic> action) {
    final round = action['round'];
    final phase = action['phase'];
    final actionType = action['actionType'];
    final sourcePlayer = action['sourcePlayerId'];
    final targetPlayer = action['targetPlayerId'];
    final metadata = action['metadata'] as Map<String, dynamic>? ?? {};

    String text = '';
    switch (actionType) {
      case 'vote':
        text = 'Player $sourcePlayer memvoting Player $targetPlayer';
        break;
      case 'eliminate':
        final reason = metadata['reason'] ?? 'unknown';
        text = 'Player $targetPlayer tereliminasi ($reason)';
        break;
      case 'skill_use':
        final role = metadata['role'] ?? 'unknown';
        if (role == 'witch' && metadata['action'] != null) {
           text = 'Player $sourcePlayer menggunakan $role ${metadata['action']} pada Player $targetPlayer';
        } else {
           text = 'Player $sourcePlayer menggunakan skill $role pada Player $targetPlayer';
        }
        break;
      default:
        text = 'Aksi tidak diketahui: $actionType';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Round $round - $phase',
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Replay Pertandingan'),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!, style: const TextStyle(color: AppColors.error)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchReplay,
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                )
              : _actions.isEmpty
                  ? const Center(
                      child: Text('Tidak ada replay untuk pertandingan ini.',
                          style: TextStyle(color: AppColors.textMuted)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _actions.length,
                      itemBuilder: (context, index) {
                        final action = _actions[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildActionIcon(action['actionType'] ?? ''),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.1),
                                    ),
                                  ),
                                  child: _buildActionText(action),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
