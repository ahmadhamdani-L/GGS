import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/guild_provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

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
        backgroundColor: Color(0xFF0F1B3D),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (guild == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1B3D),
        body: Center(child: Text("Guild tidak ditemukan", style: TextStyle(color: Colors.white))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1B3D),
      appBar: AppBar(
        title: Text(guild.name),
        backgroundColor: const Color(0xFF1A1A2E),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app, color: Colors.redAccent),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1A1A2E),
                  title: const Text("Keluar Guild", style: TextStyle(color: Colors.white)),
                  content: const Text("Yakin ingin keluar dari guild ini?", style: TextStyle(color: Colors.white70)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Keluar", style: TextStyle(color: Colors.redAccent))),
                  ],
                ),
              );
              if (confirm == true) {
                final success = await ref.read(guildProvider.notifier).leaveGuild();
                if (success && mounted) {
                  Navigator.pop(context); // Go back to where they came from
                }
              }
            },
          )
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.amber,
          labelColor: Colors.amber,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: "Info & Anggota"),
            Tab(text: "Chat Guild"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildInfoTab(state),
          _buildChatTab(state),
        ],
      ),
    );
  }

  Widget _buildInfoTab(GuildState state) {
    final guild = state.currentGuild!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Guild Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.amber.withOpacity(0.2),
                    child: Text(guild.tag, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(guild.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text("Level ${guild.level}  •  ${guild.memberCount}/${guild.maxMembers} Anggota", style: const TextStyle(color: Colors.amber)),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Text(guild.description, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text("Anggota Guild", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...state.members.map((m) {
          final bool isLeader = m.role == 'leader';
          return Card(
            color: Colors.white.withOpacity(0.05),
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isLeader ? Colors.amber : Colors.blueAccent,
                child: Icon(isLeader ? Icons.star : Icons.person, color: Colors.white, size: 18),
              ),
              title: Text(m.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text("Level ${m.level} • Bergabung ${m.joinedAt}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
              trailing: isLeader ? const Text("Ketua", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)) : const Text("Anggota", style: TextStyle(color: Colors.white70)),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildChatTab(GuildState state) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            reverse: true,
            itemCount: state.chats.length,
            itemBuilder: (context, index) {
              final chat = state.chats[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.indigo,
                      child: Text(chat.senderName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(chat.senderName, style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              Text(DateFormat('HH:mm').format(chat.createdAt), style: const TextStyle(color: Colors.white38, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(chat.content, style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Chat Input
        ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.black.withOpacity(0.3),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Tulis pesan...",
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      backgroundColor: Colors.amber,
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.black),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      ref.read(guildProvider.notifier).sendChat(widget.guildId, text);
      _chatController.clear();
    }
  }
}
