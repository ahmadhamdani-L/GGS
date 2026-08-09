import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../providers/guild_provider.dart';

class GuildDashboardPage extends ConsumerStatefulWidget {
  final String guildId;
  const GuildDashboardPage({super.key, required this.guildId});

  @override
  ConsumerState<GuildDashboardPage> createState() => _GuildDashboardPageState();
}

class _GuildDashboardPageState extends ConsumerState<GuildDashboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _chatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    Future.microtask(() => ref.read(guildProvider.notifier).fetchMyGuild(widget.guildId));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(guildProvider);
    final guild = state.currentGuild;

    if (state.isLoading && guild == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF080B10),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFDAA520))),
      );
    }

    if (guild == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF080B10),
        body: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.error.withValues(alpha: 0.1),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Glitchy/Broken shield icon
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.shield_rounded, color: AppColors.error.withValues(alpha: 0.15), size: 80),
                    const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 40),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Guild Tidak Ditemukan',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Guild ini mungkin telah dibubarkan atau kamu sudah dikeluarkan.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    // Optional: Call provider to clear my guild ID if needed
                    Navigator.pop(context);
                  },
                  child: Container(
                    height: 48,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)],
                      ),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.3), blurRadius: 8),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'KEMBALI',
                        style: TextStyle(color: Colors.black, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF080B10),
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: const Color(0xFF0D1117),
            border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3), width: 1.5),
          ),
          child: Column(
            children: [
              // ─── Top Bar ──────────────────────────
              _buildTopBar(guild),
              // ─── Guild Header Card ────────────────
              _buildGuildHeader(guild),
              // ─── Tabs ─────────────────────────────
              _buildTabs(),
              // ─── Tab Content ──────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildMembersTab(state),
                    _buildChatTab(state),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(guild) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color(0xFFDAA520).withValues(alpha: 0.15))),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.shield_rounded, color: Color(0xFFDAA520), size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              guild.name,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Leave Guild button
          GestureDetector(
            onTap: _confirmLeave,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.error.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.exit_to_app_rounded, color: AppColors.error, size: 14),
                  SizedBox(width: 4),
                  Text('Keluar', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuildHeader(guild) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFDAA520).withValues(alpha: 0.08),
            const Color(0xFF151A28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          // Guild Avatar
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [Color(0xFFB8860B), Color(0xFFDAA520)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.3), blurRadius: 12),
              ],
            ),
            child: Center(
              child: Text(
                guild.tag.toUpperCase(),
                style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Guild Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(guild.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                if (guild.description.isNotEmpty)
                  Text(
                    guild.description,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                // Stats row
                Row(
                  children: [
                    _StatBadge(icon: Icons.military_tech_rounded, label: 'Lv.${guild.level}', color: const Color(0xFFDAA520)),
                    const SizedBox(width: 10),
                    _StatBadge(icon: Icons.people_alt_rounded, label: '${guild.memberCount}/${guild.maxMembers}', color: const Color(0xFF4A9EFF)),
                    const SizedBox(width: 10),
                    _StatBadge(icon: Icons.star_rounded, label: '${guild.xp} XP', color: const Color(0xFF9C27B0)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF151A28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520)]),
          borderRadius: BorderRadius.circular(8),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: AppColors.textMuted,
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: const [
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.people_alt_rounded, size: 16),
            SizedBox(width: 6),
            Text('Anggota'),
          ])),
          Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.chat_bubble_rounded, size: 16),
            SizedBox(width: 6),
            Text('Chat'),
          ])),
        ],
      ),
    );
  }

  Widget _buildMembersTab(GuildState state) {
    if (state.members.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline_rounded, color: Colors.white.withValues(alpha: 0.15), size: 48),
            const SizedBox(height: 12),
            const Text('Belum ada anggota', style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      itemCount: state.members.length,
      itemBuilder: (context, index) {
        final member = state.members[index];
        final isLeader = member.role == 'leader';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF151A28),
            border: Border.all(
              color: isLeader
                  ? const Color(0xFFDAA520).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isLeader
                        ? [const Color(0xFFDAA520), const Color(0xFFB8860B)]
                        : [const Color(0xFF4A9EFF), const Color(0xFF2979FF)],
                  ),
                ),
                child: Center(
                  child: Icon(
                    isLeader ? Icons.star_rounded : Icons.person_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.displayName,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isLeader) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: const Color(0xFFDAA520).withValues(alpha: 0.15),
                            ),
                            child: const Text('Ketua', style: TextStyle(color: Color(0xFFDAA520), fontSize: 9, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Level ${member.level} • Bergabung ${member.joinedAt}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChatTab(GuildState state) {
    return Column(
      children: [
        // Chat messages
        Expanded(
          child: state.chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, color: Colors.white.withValues(alpha: 0.15), size: 48),
                      const SizedBox(height: 12),
                      const Text('Belum ada pesan', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
                      const SizedBox(height: 4),
                      const Text('Mulai obrolan dengan anggota guild!', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  reverse: true,
                  itemCount: state.chats.length,
                  itemBuilder: (context, index) {
                    final chat = state.chats[index];
                    return _ChatBubble(chat: chat);
                  },
                ),
        ),
        // Chat input
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: const Color(0xFF151A28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: TextField(
                    controller: _chatController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Tulis pesan...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520)]),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.3), blurRadius: 8),
                    ],
                  ),
                  child: const Center(child: Icon(Icons.send_rounded, color: Colors.black, size: 18)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      HapticFeedback.lightImpact();
      ref.read(guildProvider.notifier).sendChat(widget.guildId, text);
      _chatController.clear();
    }
  }

  void _confirmLeave() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF151A28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: AppColors.error, size: 24),
            SizedBox(width: 8),
            Text('Keluar Guild', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          ],
        ),
        content: const Text(
          'Yakin ingin meninggalkan guild ini? Kamu harus bergabung kembali jika ingin kembali.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Keluar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await ref.read(guildProvider.notifier).leaveGuild();
      if (success && mounted) {
        Navigator.pop(context);
      }
    }
  }
}

// ─── Reusable Widgets ────────────────────────────────────────

class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final dynamic chat;
  const _ChatBubble({required this.chat});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [const Color(0xFF4A9EFF).withValues(alpha: 0.6), const Color(0xFF2979FF)],
              ),
            ),
            child: Center(
              child: Text(
                chat.senderName.isNotEmpty ? chat.senderName[0].toUpperCase() : '?',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      chat.senderName,
                      style: const TextStyle(color: Color(0xFFDAA520), fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('HH:mm').format(chat.createdAt),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                    color: const Color(0xFF1A1F2E),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                  child: Text(chat.content, style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
