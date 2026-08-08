import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/audio_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  late double _bgmVolume;
  late double _sfxVolume;
  late bool _bgmEnabled;
  late bool _sfxEnabled;

  @override
  void initState() {
    super.initState();
    final audio = ref.read(audioServiceProvider);
    _bgmVolume = audio.bgmVolume;
    _sfxVolume = audio.sfxVolume;
    _bgmEnabled = audio.bgmEnabled;
    _sfxEnabled = audio.sfxEnabled;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final profile = auth.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header
            Row(children: [
              IconButton(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
              ),
              const SizedBox(width: 8),
              const Text('Pengaturan', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 28),

            // Account section
            _sectionTitle('Akun'),
            const SizedBox(height: 10),
            _buildAccountCard(profile),
            const SizedBox(height: 24),

            // Audio section
            _sectionTitle('Audio'),
            const SizedBox(height: 10),
            _buildAudioCard(),
            const SizedBox(height: 24),

            // About section
            _sectionTitle('Tentang'),
            const SizedBox(height: 10),
            _buildAboutCard(),
            const SizedBox(height: 32),

            // Logout
            _buildLogoutButton(),
            const SizedBox(height: 12),

            // Delete Account
            _buildDeleteAccountButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(color: Color(0xFFDAA520), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1));
  }

  Widget _buildAccountCard(dynamic profile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            _infoRow(Icons.person_rounded, 'Nama', profile?.displayName ?? 'Player'),
            const Divider(color: AppColors.border, height: 24),
            _infoRow(Icons.star_rounded, 'Level', 'Lv.${profile?.level ?? 1}'),
            const Divider(color: AppColors.border, height: 24),
            _infoRow(Icons.monetization_on_rounded, 'Koin', '${profile?.coins ?? 0}'),
            const Divider(color: AppColors.border, height: 24),
            _infoRow(Icons.emoji_events_rounded, 'Games Won', '${profile?.gamesWon ?? 0}'),
          ]),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(children: [
      Icon(icon, color: const Color(0xFFDAA520), size: 20),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      const Spacer(),
      Text(value, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
    ]);
  }

  Widget _buildAudioCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            // BGM toggle + slider
            Row(children: [
              const Icon(Icons.music_note_rounded, color: AppColors.blueTeam, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('Musik', style: TextStyle(color: AppColors.textSecondary, fontSize: 14))),
              Switch(
                value: _bgmEnabled,
                onChanged: (v) {
                  setState(() => _bgmEnabled = v);
                  ref.read(audioServiceProvider).toggleBgm(v);
                },
                activeThumbColor: const Color(0xFFDAA520),
              ),
            ]),
            if (_bgmEnabled) Slider(
              value: _bgmVolume,
              onChanged: (v) {
                setState(() => _bgmVolume = v);
                ref.read(audioServiceProvider).setBgmVolume(v);
              },
              activeColor: AppColors.blueTeam,
              inactiveColor: AppColors.border,
            ),
            const Divider(color: AppColors.border, height: 16),
            // SFX toggle + slider
            Row(children: [
              const Icon(Icons.volume_up_rounded, color: AppColors.success, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('Efek Suara', style: TextStyle(color: AppColors.textSecondary, fontSize: 14))),
              Switch(
                value: _sfxEnabled,
                onChanged: (v) {
                  setState(() => _sfxEnabled = v);
                  ref.read(audioServiceProvider).toggleSfx(v);
                },
                activeThumbColor: const Color(0xFFDAA520),
              ),
            ]),
            if (_sfxEnabled) Slider(
              value: _sfxVolume,
              onChanged: (v) {
                setState(() => _sfxVolume = v);
                ref.read(audioServiceProvider).setSfxVolume(v);
              },
              activeColor: AppColors.success,
              inactiveColor: AppColors.border,
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildAboutCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1F2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
          ),
          child: Column(children: [
            _infoRow(Icons.info_outline_rounded, 'Versi', '1.0.0'),
            const Divider(color: AppColors.border, height: 24),
            _infoRow(Icons.code_rounded, 'Stack', 'Flutter + Go'),
            const Divider(color: AppColors.border, height: 24),
            _infoRow(Icons.sports_esports_rounded, 'Game', 'Werewolf Red vs Blue'),
          ]),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    // #5 FIX: confirmation dialog sebelum logout
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => _showLogoutConfirmation(context),
        icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
        label: const Text('Keluar', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.logout_rounded, color: AppColors.error),
          SizedBox(width: 8),
          Text('Keluar?',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        ]),
        content: const Text(
          'Yakin ingin keluar dari akun ini?',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
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
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      ref.read(authProvider.notifier).logout();
      context.go('/auth');
    }
  }

  Widget _buildDeleteAccountButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () => _showDeleteAccountDialog(context),
        icon: Icon(Icons.delete_forever_rounded, size: 18,
          color: Colors.red.shade900),
        label: Text('Hapus Akun Permanen',
          style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.red.shade900.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final passwordCtrl = TextEditingController();
    final isGuest = ref.read(authProvider).profile?.isGuest ?? false;
    bool deleting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
            const SizedBox(width: 8),
            const Text('Hapus Akun?',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text(
              'PERINGATAN: Aksi ini tidak bisa dibatalkan!\n\n'
              'Semua data akan dihapus permanen:\n'
              '• Profil & statistik\n'
              '• Diamond & inventori\n'
              '• Riwayat pertandingan\n'
              '• Foto avatar\n'
              '• Pertemanan',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.5),
            ),
            if (!isGuest) ...[
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Masukkan password untuk konfirmasi',
                  prefixIcon: const Icon(Icons.lock_outline, size: 18),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ]),
          actions: [
            TextButton(onPressed: deleting ? null : () => Navigator.pop(ctx, false),
              child: const Text('Batal', style: TextStyle(color: AppColors.textMuted))),
            ElevatedButton(
              onPressed: deleting ? null : () async {
                if (!isGuest && passwordCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Password wajib diisi'), backgroundColor: AppColors.warning));
                  return;
                }
                setDialogState(() => deleting = true);
                final api = ref.read(apiServiceProvider);
                final res = await api.deleteAccount(
                  password: isGuest ? null : passwordCtrl.text);
                if (!ctx.mounted) return;
                if (res.isSuccess) {
                  Navigator.pop(ctx, true);
                } else {
                  setDialogState(() => deleting = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(res.error ?? 'Gagal menghapus akun'),
                    backgroundColor: AppColors.error));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              child: deleting
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Hapus Permanen', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    passwordCtrl.dispose();
    if (confirmed == true && mounted) {
      ref.read(authProvider.notifier).logout();
      context.go('/auth');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Akun berhasil dihapus. Selamat tinggal!'),
        backgroundColor: AppColors.success));
    }
  }
}