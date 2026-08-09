import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/guild_provider.dart';
import '../../models/guild.dart';

class GuildLandingPage extends ConsumerStatefulWidget {
  const GuildLandingPage({super.key});

  @override
  ConsumerState<GuildLandingPage> createState() => _GuildLandingPageState();
}

class _GuildLandingPageState extends ConsumerState<GuildLandingPage> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    Future.microtask(() => ref.read(guildProvider.notifier).searchGuilds(""));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  void _createGuildDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CreateGuildSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(guildProvider);

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
              // ─── Top Bar ────────────────────────────
              _buildTopBar(),
              // ─── Search Bar ─────────────────────────
              _buildSearchBar(),
              const SizedBox(height: 8),
              // ─── Content ────────────────────────────
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFDAA520)))
                    : state.searchResults.isEmpty
                        ? _buildEmptyState()
                        : _buildGuildList(state.searchResults),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
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
          const Icon(Icons.shield_rounded, color: Color(0xFFDAA520), size: 24),
          const SizedBox(width: 8),
          const Text('Guild', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const Spacer(),
          // Create Guild button
          GestureDetector(
            onTap: _createGuildDialog,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520)]),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.3), blurRadius: 8),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, color: Colors.black, size: 16),
                  SizedBox(width: 4),
                  Text('Buat', style: TextStyle(color: Colors.black, fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF1A1F2E),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Cari nama atau tag guild...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.4), size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onSubmitted: (val) {
            ref.read(guildProvider.notifier).searchGuilds(val);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, color: Colors.white.withValues(alpha: 0.15), size: 56),
          const SizedBox(height: 16),
          const Text('Tidak ada guild ditemukan', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          const SizedBox(height: 8),
          const Text('Coba kata kunci lain atau buat guild baru', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGuildList(List<Guild> guilds) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: guilds.length,
      itemBuilder: (context, index) {
        final guild = guilds[index];
        return _GuildCard(guild: guild, onJoin: () => _handleJoin(guild));
      },
    );
  }

  void _handleJoin(Guild guild) async {
    HapticFeedback.mediumImpact();
    final success = await ref.read(guildProvider.notifier).joinGuild(guild.id);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Berhasil bergabung ke ${guild.name}! ⚔️'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.read(guildProvider).error ?? 'Gagal bergabung'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// GUILD CARD
// ═══════════════════════════════════════════════════════════════

class _GuildCard extends StatelessWidget {
  final Guild guild;
  final VoidCallback onJoin;
  const _GuildCard({required this.guild, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF151A28),
        border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          // Guild Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [const Color(0xFFDAA520).withValues(alpha: 0.3), const Color(0xFFB8860B).withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.4)),
            ),
            child: Center(
              child: Text(
                guild.tag.length > 2 ? guild.tag.substring(0, 2).toUpperCase() : guild.tag.toUpperCase(),
                style: const TextStyle(color: Color(0xFFDAA520), fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Guild Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        guild.name,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: const Color(0xFFDAA520).withValues(alpha: 0.15),
                      ),
                      child: Text('[${guild.tag}]', style: const TextStyle(color: Color(0xFFDAA520), fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _InfoChip(icon: Icons.military_tech_rounded, label: 'Lv.${guild.level}'),
                    const SizedBox(width: 10),
                    _InfoChip(icon: Icons.people_alt_rounded, label: '${guild.memberCount}/${guild.maxMembers}'),
                    if (guild.isPublic) ...[
                      const SizedBox(width: 10),
                      _InfoChip(icon: Icons.public_rounded, label: 'Publik'),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Join Button
          GestureDetector(
            onTap: onJoin,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF4A9EFF).withValues(alpha: 0.15),
                border: Border.all(color: const Color(0xFF4A9EFF).withValues(alpha: 0.4)),
              ),
              child: const Text('Gabung', style: TextStyle(color: Color(0xFF4A9EFF), fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.textMuted, size: 13),
        const SizedBox(width: 3),
        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CREATE GUILD BOTTOM SHEET (Premium Design)
// ═══════════════════════════════════════════════════════════════

class _CreateGuildSheet extends ConsumerStatefulWidget {
  const _CreateGuildSheet();

  @override
  ConsumerState<_CreateGuildSheet> createState() => _CreateGuildSheetState();
}

class _CreateGuildSheetState extends ConsumerState<_CreateGuildSheet> {
  final _nameCtrl = TextEditingController();
  final _tagCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isCreating = false;
  String? _errorText;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _tagCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _handleCreate() async {
    final name = _nameCtrl.text.trim();
    final tag = _tagCtrl.text.trim();
    final desc = _descCtrl.text.trim();

    // Validation
    if (name.length < 3 || name.length > 20) {
      setState(() => _errorText = 'Nama guild harus 3-20 karakter');
      return;
    }
    if (tag.length < 2 || tag.length > 6) {
      setState(() => _errorText = 'Tag harus 2-6 karakter');
      return;
    }

    setState(() {
      _isCreating = true;
      _errorText = null;
    });

    HapticFeedback.mediumImpact();
    final success = await ref.read(guildProvider.notifier).createGuild(name, tag, desc);

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Guild "$name" berhasil dibuat! 🛡️'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ));
    } else {
      setState(() {
        _isCreating = false;
        _errorText = ref.read(guildProvider).error ?? 'Gagal membuat guild';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1117),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Color(0xFFDAA520), width: 1.5),
            left: BorderSide(color: Color(0xFFDAA520), width: 0.5),
            right: BorderSide(color: Color(0xFFDAA520), width: 0.5),
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Row(
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFFDAA520), size: 28),
                  SizedBox(width: 10),
                  Text('Buat Guild Baru', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Buat guild-mu sendiri dan rekrut anggota untuk bertarung bersama!',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 24),
              // Name field
              _GuildTextField(
                controller: _nameCtrl,
                label: 'Nama Guild',
                hint: 'Masukkan nama guild (3-20 karakter)',
                icon: Icons.edit_rounded,
                maxLength: 20,
              ),
              const SizedBox(height: 16),
              // Tag field
              _GuildTextField(
                controller: _tagCtrl,
                label: 'Tag Guild',
                hint: 'Tag singkat (2-6 karakter)',
                icon: Icons.tag_rounded,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 16),
              // Description field
              _GuildTextField(
                controller: _descCtrl,
                label: 'Deskripsi (Opsional)',
                hint: 'Deskripsikan guild kamu...',
                icon: Icons.description_rounded,
                maxLines: 3,
                maxLength: 200,
              ),
              const SizedBox(height: 16),
              // Error
              if (_errorText != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.error.withValues(alpha: 0.1),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorText!, style: const TextStyle(color: AppColors.error, fontSize: 12))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Create Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isCreating ? null : _handleCreate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDAA520),
                    disabledBackgroundColor: const Color(0xFFDAA520).withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isCreating
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black))
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shield_rounded, color: Colors.black, size: 20),
                            SizedBox(width: 8),
                            Text('Buat Guild', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w800)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuildTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;

  const _GuildTextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFF151A28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            maxLines: maxLines,
            maxLength: maxLength,
            textCapitalization: textCapitalization,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 13),
              prefixIcon: Icon(icon, color: const Color(0xFFDAA520).withValues(alpha: 0.6), size: 18),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}
