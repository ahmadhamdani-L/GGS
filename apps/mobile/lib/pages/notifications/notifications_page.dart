import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});
  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.getNotifications();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isSuccess && res.data != null) {
        _notifications = List<Map<String, dynamic>>.from(res.data!['notifications'] as List? ?? []);
      }
    });
  }

  Future<void> _markAllRead() async {
    final api = ref.read(apiServiceProvider);
    await api.markAllNotificationsRead();
    if (!mounted) return;
    setState(() {
      for (var n in _notifications) {
        n['isRead'] = true;
      }
    });
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return '${diff.inSeconds}d lalu';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24)    return '${diff.inHours}j lalu';
    if (diff.inDays < 7)      return '${diff.inDays}h lalu';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'gift_received':          return Icons.card_giftcard_rounded;
      case 'achievement_unlocked':   return Icons.emoji_events_rounded;
      case 'friend_request':         return Icons.person_add_rounded;
      case 'game_invite':            return Icons.sports_esports_rounded;
      case 'missions_reset':         return Icons.assignment_rounded;
      case 'diamond_topup':          return Icons.diamond_rounded;
      case 'level_up':               return Icons.trending_up_rounded;
      default:                       return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'gift_received':          return AppColors.primary;
      case 'achievement_unlocked':   return const Color(0xFFFFD700);
      case 'friend_request':         return AppColors.blueTeam;
      case 'game_invite':            return AppColors.success;
      case 'diamond_topup':          return const Color(0xFF7B2FBE);
      default:                       return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => n['isRead'] != true).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 8),
            const Text('Notifikasi', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const Spacer(),
            if (unreadCount > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity( 0.15),
                  borderRadius: BorderRadius.circular(12)),
                child: Text('$unreadCount baru',
                  style: const TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _markAllRead,
                child: const Text('Baca semua',
                  style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ]),
        ),
        // List
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _notifications.isEmpty
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.notifications_off_rounded, color: AppColors.textMuted, size: 48),
                  SizedBox(height: 12),
                  Text('Belum ada notifikasi', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) => _buildTile(_notifications[i]),
                  ),
                ),
        ),
      ])),
    );
  }

  Widget _buildTile(Map<String, dynamic> n) {
    final type    = n['type'] as String? ?? '';
    final title   = n['title'] as String? ?? '';
    final message = n['message'] as String? ?? '';
    final isRead  = n['isRead'] as bool? ?? false;
    final time    = _timeAgo(n['createdAt'] as String?);
    final color   = _colorFor(type);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead
            ? Colors.white.withOpacity( 0.02)
            : color.withOpacity( 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isRead
              ? Colors.white.withOpacity( 0.04)
              : color.withOpacity( 0.2)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Icon
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity( 0.15), shape: BoxShape.circle),
          child: Icon(_iconFor(type), color: color, size: 18),
        ),
        const SizedBox(width: 12),
        // Content
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: isRead ? FontWeight.w500 : FontWeight.w700))),
            Text(time, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ]),
          const SizedBox(height: 3),
          Text(message,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
        // Unread dot
        if (!isRead)
          Container(
            width: 8, height: 8, margin: const EdgeInsets.only(top: 4, left: 6),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
      ]),
    );
  }
}
