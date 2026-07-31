import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';

/// Notification model
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'system',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      isRead: json['isRead'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      data: json['data'] as Map<String, dynamic>?,
    );
  }

  String get emoji {
    switch (type) {
      case 'friend_request':
        return '👋';
      case 'friend_accepted':
        return '🤝';
      case 'game_invite':
        return '🎮';
      case 'achievement_unlocked':
        return '🏆';
      case 'mission_complete':
        return '📋';
      case 'level_up':
        return '⬆️';
      case 'daily_reward':
        return '🎁';
      default:
        return '🔔';
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24) return '${diff.inHours}h lalu';
    if (diff.inDays < 7) return '${diff.inDays}d lalu';
    return '${createdAt.day}/${createdAt.month}';
  }
}

/// Notifications provider
final notificationsProvider = StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref);
});

class NotificationsState {
  final List<AppNotification> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationsState copyWith({
    List<AppNotification>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final Ref ref;

  NotificationsNotifier(this.ref) : super(const NotificationsState());

  ApiService get _api => ref.read(apiServiceProvider);

  Future<void> loadNotifications() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    state = state.copyWith(isLoading: true, error: null);

    final response = await _api.getNotifications();
    if (response.isSuccess && response.data != null) {
      final notifList = response.data!['notifications'] as List<dynamic>? ?? [];
      final notifications = notifList.map((n) => AppNotification.fromJson(n as Map<String, dynamic>)).toList();
      final unreadCount = response.data!['unreadCount'] as int? ?? 0;
      state = state.copyWith(
        notifications: notifications,
        unreadCount: unreadCount,
        isLoading: false,
      );
    } else {
      state = state.copyWith(isLoading: false, error: response.error);
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    final response = await _api.markNotificationRead(notificationId);
    
    if (response.isSuccess) {
      final updated = state.notifications.map((n) {
        if (n.id == notificationId) {
          return AppNotification(
            id: n.id,
            type: n.type,
            title: n.title,
            message: n.message,
            isRead: true,
            createdAt: n.createdAt,
            data: n.data,
          );
        }
        return n;
      }).toList();
      final unreadCount = updated.where((n) => !n.isRead).length;
      state = state.copyWith(notifications: updated, unreadCount: unreadCount);
    }
  }

  Future<void> markAllAsRead() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    final response = await _api.markAllNotificationsRead();
    
    if (response.isSuccess) {
      final updated = state.notifications.map((n) => AppNotification(
        id: n.id,
        type: n.type,
        title: n.title,
        message: n.message,
        isRead: true,
        createdAt: n.createdAt,
        data: n.data,
      )).toList();
      state = state.copyWith(notifications: updated, unreadCount: 0);
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;

    final response = await _api.deleteNotification(notificationId);
    
    if (response.isSuccess) {
      final updated = state.notifications.where((n) => n.id != notificationId).toList();
      final unreadCount = updated.where((n) => !n.isRead).length;
      state = state.copyWith(notifications: updated, unreadCount: unreadCount);
    }
  }
}

/// Notification bell icon with badge count
class NotificationBell extends ConsumerStatefulWidget {
  final VoidCallback? onTap;

  const NotificationBell({super.key, this.onTap});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(notificationsProvider.notifier).loadNotifications());
  }

  @override
  Widget build(BuildContext context) {
    final notifState = ref.watch(notificationsProvider);
    final count = notifState.unreadCount;

    return GestureDetector(
      onTap: widget.onTap ?? () => _showNotifications(context),
      child: Stack(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 20),
          ),
          if (count > 0)
            Positioned(
              right: 0, top: 0,
              child: Container(
                width: 16, height: 16,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.error,
                ),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const _NotificationSheet(),
    );
  }
}

class _NotificationSheet extends ConsumerWidget {
  const _NotificationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifState = ref.watch(notificationsProvider);
    final notifications = notifState.notifications;

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Row(children: [
              const Text('Notifikasi', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (notifState.unreadCount > 0)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(notificationsProvider.notifier).markAllAsRead();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: const Text('Baca Semua', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: notifState.isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : notifications.isEmpty
                      ? const Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('🔔', style: TextStyle(fontSize: 40)),
                            SizedBox(height: 12),
                            Text('Tidak ada notifikasi', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                          ]),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: notifications.length,
                          itemBuilder: (_, i) => _buildNotificationItem(context, ref, notifications[i]),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, WidgetRef ref, AppNotification n) {
    return Dismissible(
      key: Key(n.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      onDismissed: (_) => ref.read(notificationsProvider.notifier).deleteNotification(n.id),
      child: GestureDetector(
        onTap: () {
          if (!n.isRead) {
            ref.read(notificationsProvider.notifier).markAsRead(n.id);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: n.isRead ? AppColors.surfaceElevated : AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: n.isRead ? null : Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.title, style: TextStyle(
                color: n.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 2),
              Text(n.message, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(n.timeAgo, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
              if (!n.isRead) ...[
                const SizedBox(height: 4),
                Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary)),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}
