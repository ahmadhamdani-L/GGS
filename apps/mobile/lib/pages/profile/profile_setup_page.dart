import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../pages/tutorial/tutorial_page.dart';
import '../../providers/auth_provider.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _nameController = TextEditingController();
  int _selectedAvatar = 1;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(authProvider).profile;
    if (profile != null && profile.displayName != 'Player') {
      _nameController.text = profile.displayName;
      _selectedAvatar = profile.avatarId;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama minimal 2 karakter')),
      );
      return;
    }

    setState(() => _saving = true);
    final notifier = ref.read(authProvider.notifier);
    await notifier.updateProfile(
          displayName: name,
          avatarId: _selectedAvatar,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    
    // Check if this is first time (tutorial not completed)
    final prefs = await SharedPreferences.getInstance();
    final tutorialCompleted = prefs.getBool(kTutorialCompletedKey) ?? false;
    
    if (!mounted) return;
    if (!tutorialCompleted) {
      // First time user - show onboarding tutorial
      context.go('/onboarding');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Header
              const Text(
                'Buat Profil',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Pilih avatar dan nama tampilanmu',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              // Selected avatar preview with glow
              Center(
                child: Container(
                  width: 100,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary, width: 3),
                    boxShadow: [
                      BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Image.asset(
                      AppConstants.avatarPath(_selectedAvatar),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 40, color: AppColors.textMuted),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // Avatar grid
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: AppConstants.avatarCount,
                        itemBuilder: (context, index) {
                          final id = index + 1;
                          final selected = _selectedAvatar == id;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedAvatar = id),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: selected ? AppColors.primary : Colors.white.withValues(alpha: 0.08),
                                  width: selected ? 2.5 : 1,
                                ),
                                boxShadow: selected
                                    ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 12)]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Image.asset(
                                    AppConstants.avatarPath(id),
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      color: AppColors.surfaceElevated,
                                      child: Center(child: Text('$id', style: const TextStyle(color: AppColors.textMuted))),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Name input
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Nama Tampilan',
                  prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.textMuted, size: 20),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
                maxLength: 16,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                    Text('$currentLength/16', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ),
              const SizedBox(height: 16),
              // Save button
              GradientButton(
                label: 'Mulai Main',
                icon: Icons.play_arrow_rounded,
                gradient: AppColors.primaryGradient,
                onPressed: _saving ? null : _save,
                isLoading: _saving,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
