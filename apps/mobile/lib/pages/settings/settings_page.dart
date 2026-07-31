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
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1));
  }

  Widget _buildAccountCard(dynamic profile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
      Icon(icon, color: AppColors.primary, size: 20),
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
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                activeColor: AppColors.primary,
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
                activeColor: AppColors.primary,
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
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () {
          ref.read(authProvider.notifier).logout();
          context.go('/auth');
        },
        icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.error),
        label: const Text('Keluar', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.error.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
