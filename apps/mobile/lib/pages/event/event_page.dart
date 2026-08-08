import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class EventPage extends ConsumerStatefulWidget {
  const EventPage({super.key});

  @override
  ConsumerState<EventPage> createState() => _EventPageState();
}

class _EventPageState extends ConsumerState<EventPage> {
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.getEvents();
    if (res.isSuccess && res.data != null) {
      final list = res.data!['events'] as List<dynamic>? ?? [];
      setState(() {
        _events = list.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _claimReward(String eventId) async {
    HapticFeedback.mediumImpact();
    final api = ref.read(apiServiceProvider);
    final res = await api.claimEventReward(eventId);
    if (res.isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🎉 Reward berhasil diklaim!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0F14),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Events', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDAA520)))
          : _events.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  color: const Color(0xFFDAA520),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _events.length,
                    itemBuilder: (ctx, i) => _EventCard(
                      event: _events[i],
                      onClaim: () {
                        final eventData = _events[i]['event'] as Map<String, dynamic>?;
                        if (eventData != null) _claimReward(eventData['id'] ?? '');
                      },
                    ),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🎪', style: TextStyle(fontSize: 48)),
          SizedBox(height: 12),
          Text('Belum ada event aktif', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  final VoidCallback onClaim;

  const _EventCard({required this.event, required this.onClaim});

  @override
  Widget build(BuildContext context) {
    final eventData = event['event'] as Map<String, dynamic>? ?? {};
    final progress = event['progress'] as Map<String, dynamic>?;
    final name = eventData['name'] ?? 'Event';
    final description = eventData['description'] ?? '';
    final emoji = eventData['bannerEmoji'] ?? '🎃';
    final rewards = (eventData['rewards'] as List<dynamic>?) ?? [];
    final requirements = eventData['requirements'] as Map<String, dynamic>? ?? {};
    final endAt = eventData['endAt'] ?? '';
    final claimed = progress?['claimed'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(colors: [
          const Color(0xFF1A0E2E),
          const Color(0xFF1A1D2E).withOpacity( 0.9),
        ]),
        border: Border.all(color: const Color(0xFFDAA520).withOpacity( 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(description, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11), maxLines: 2),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Requirements
          if (requirements.isNotEmpty) ...[
            const Text('Syarat:', style: TextStyle(color: Color(0xFFDAA520), fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: requirements.entries.map((e) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFFDAA520).withOpacity( 0.1),
                    border: Border.all(color: const Color(0xFFDAA520).withOpacity( 0.2)),
                  ),
                  child: Text('${_formatKey(e.key)}: ${e.value}', style: const TextStyle(color: Color(0xFFDAA520), fontSize: 10)),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          // Rewards
          if (rewards.isNotEmpty) ...[
            const Text('Hadiah:', style: TextStyle(color: Color(0xFF4ADE80), fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: rewards.map((r) {
                final type = r['type'] ?? '';
                final amount = r['amount'] ?? 0;
                final icon = type == 'coins' ? '🪙' : type == 'diamonds' ? '💎' : '⭐';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: const Color(0xFF4ADE80).withOpacity( 0.1),
                  ),
                  child: Text('$icon $amount', style: const TextStyle(color: Color(0xFF4ADE80), fontSize: 11, fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          // Time remaining
          if (endAt.isNotEmpty)
            Row(
              children: [
                const Icon(Icons.access_time_rounded, color: Color(0xFF9CA3AF), size: 12),
                const SizedBox(width: 4),
                Text(_timeRemaining(endAt), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10)),
              ],
            ),
          const SizedBox(height: 10),
          // Claim button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: claimed ? null : onClaim,
              style: ElevatedButton.styleFrom(
                backgroundColor: claimed ? const Color(0xFF374151) : const Color(0xFFDAA520),
                foregroundColor: claimed ? const Color(0xFF9CA3AF) : Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
              child: Text(claimed ? 'Sudah Diklaim ✓' : 'Klaim Reward', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    return key.replaceAll('_', ' ').split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  String _timeRemaining(String endAt) {
    try {
      final end = DateTime.parse(endAt);
      final diff = end.difference(DateTime.now());
      if (diff.isNegative) return 'Berakhir';
      if (diff.inDays > 0) return '${diff.inDays} hari lagi';
      if (diff.inHours > 0) return '${diff.inHours} jam lagi';
      return '${diff.inMinutes} menit lagi';
    } catch (_) {
      return '';
    }
  }
}
