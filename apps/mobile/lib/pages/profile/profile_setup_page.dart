import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../pages/tutorial/tutorial_page.dart';
import '../../providers/auth_provider.dart';
import 'profile_name_validator.dart';

class ProfileSetupPage extends ConsumerStatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  ConsumerState<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends ConsumerState<ProfileSetupPage> {
  final _nameController  = TextEditingController();
  final _imagePicker     = ImagePicker();
  int    _selectedAvatar = 1;
  bool   _saving         = false;

  // Custom photo state
  File?  _customPhoto;       // local File after crop (before upload)
  String? _uploadedAvatarUrl; // server URL after successful upload
  bool   _uploading  = false;
  String? _uploadError;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_handleNameChanged);
    final profile = ref.read(authProvider).profile;
    if (profile != null && profile.displayName != 'Player') {
      _nameController.text = profile.displayName;
      _selectedAvatar = profile.avatarId;
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_handleNameChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _handleNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // ─── Image Picker ─────────────────────────────────────────

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Text('Pilih Sumber Foto',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary),
            title: const Text('Kamera', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.camera); },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
            title: const Text('Galeri Foto', style: TextStyle(color: AppColors.textPrimary)),
            onTap: () { Navigator.pop(ctx); _pickImage(ImageSource.gallery); },
          ),
          if (_customPhoto != null || _uploadedAvatarUrl != null)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Hapus Foto Custom', style: TextStyle(color: AppColors.error)),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _customPhoto = null;
                  _uploadedAvatarUrl = null;
                  _uploadError = null;
                });
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _imagePicker.pickImage(
        source:     source,
        maxWidth:   1024,
        maxHeight:  1024,
        imageQuality: 90,
      );
      if (picked == null) return;

      // Crop to square
      final CroppedFile? cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Avatar',
            toolbarColor: const Color(0xFF1a1a2e),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.primary,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: 'Crop Avatar',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );
      if (cropped == null) return;

      setState(() {
        _customPhoto   = File(cropped.path);
        _uploadedAvatarUrl = null; // will upload when saving
        _uploadError   = null;
      });

      // Auto-upload immediately so user gets instant feedback
      await _uploadPhoto();
    } catch (e) {
      if (mounted) {
        setState(() => _uploadError = 'Gagal memilih foto: $e');
      }
    }
  }

  Future<void> _uploadPhoto() async {
    if (_customPhoto == null) return;
    setState(() { _uploading = true; _uploadError = null; });

    final api  = ref.read(apiServiceProvider);

    // Retry on timeout/network failures
    const maxAttempts = 3;
    int attempt = 0;
    var resp;

    while (attempt < maxAttempts) {
      attempt++;
      resp = await api.uploadAvatar(_customPhoto!.path);
      if (resp.isSuccess && resp.data != null) break;

      // If transient/network timeout (statusCode 408 or 0) then retry
      if (resp.statusCode == 408 || resp.statusCode == 0) {
        await Future.delayed(Duration(milliseconds: 200 * attempt));
        continue;
      }
      break;
    }

    if (!mounted) return;

    if (resp != null && resp.isSuccess && resp.data != null) {
      setState(() {
        _uploadedAvatarUrl = resp!.data!['avatarUrl'] as String?;
        _uploading = false;
      });
    } else {
      setState(() {
        _uploadError = resp?.error ?? 'Upload gagal — akan pakai preset avatar';
        _uploading   = false;
      });
    }
  }

  // ─── Save profile ─────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final validationMessage = validateDisplayName(name);
    if (validationMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(validationMessage), backgroundColor: AppColors.warning));
      return;
    }
    if (_uploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tunggu foto selesai di-upload...'),
          backgroundColor: AppColors.warning));
      return;
    }

    setState(() => _saving = true);

    final notifier = ref.read(authProvider.notifier);
    try {
      await notifier.updateProfile(
        displayName: name,
        avatarId:    _selectedAvatar,
        avatarUrl:   _uploadedAvatarUrl, // null if using preset
      );

      if (!mounted) return;

      // Verify update reflected in state; authProvider.updateProfile doesn't return success bool
      final updated = ref.read(authProvider).profile;
      final bool success = updated != null && (
        updated.displayName == name ||
        updated.avatarUrl == _uploadedAvatarUrl ||
        updated.avatarId == _selectedAvatar
      );

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan profil. Silakan coba lagi.'), backgroundColor: AppColors.error),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final tutorialDone = prefs.getBool(kTutorialCompletedKey) ?? false;
      if (!mounted) return;
      context.go(tutorialDone ? '/home' : '/onboarding');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────

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
              const Text('Buat Profil',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 24,
                  fontWeight: FontWeight.w800),
                textAlign: TextAlign.center),
              const SizedBox(height: 4),
              const Text('Pilih foto atau avatar, lalu masukkan namamu',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center),
              const SizedBox(height: 28),

              // ── Avatar preview ──────────────────────────────
              Center(child: Stack(clipBehavior: Clip.none, children: [
                GestureDetector(
                  onTap: _showPhotoSourceSheet,
                  child: Container(
                    width: 110, height: 130,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _uploadedAvatarUrl != null
                            ? AppColors.success
                            : AppColors.primary,
                        width: 3),
                      boxShadow: [BoxShadow(
                        color: (_uploadedAvatarUrl != null
                            ? AppColors.success
                            : AppColors.primary).withOpacity( 0.35),
                        blurRadius: 24, spreadRadius: 2)],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: _buildAvatarPreview(),
                    ),
                  ),
                ),
                // Camera button overlay (bottom-right)
                Positioned(
                  bottom: -6, right: -6,
                  child: GestureDetector(
                    onTap: _showPhotoSourceSheet,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
                      ),
                      child: _uploading
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ])),

              // Upload status
              const SizedBox(height: 12),
              if (_uploading)
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                  SizedBox(width: 8),
                  Text('Mengupload foto...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ])
              else if (_uploadedAvatarUrl != null)
                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                  SizedBox(width: 6),
                  Text('Foto berhasil diupload ✓',
                    style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600)),
                ])
              else if (_uploadError != null)
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.warning, size: 16),
                  const SizedBox(width: 6),
                  Flexible(child: Text(_uploadError!,
                    style: const TextStyle(color: AppColors.warning, fontSize: 11))),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _uploadPhoto,
                    child: const Text('Coba lagi',
                      style: TextStyle(color: AppColors.primary, fontSize: 11,
                        fontWeight: FontWeight.w700))),
                ])
              else
                const Text(
                  'Tap foto di atas untuk upload avatar',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  textAlign: TextAlign.center,
                ),

              const Spacer(),

              const SizedBox(height: 18),
              // ── Name input ──────────────────────────────────
              TextField(
                controller: _nameController,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 16,
                  fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Nama Tampilan',
                  prefixIcon: const Icon(Icons.badge_outlined,
                    color: AppColors.textMuted, size: 20),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity( 0.08))),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withOpacity( 0.08))),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
                ),
                maxLength: 16,
                buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                    Text('$currentLength/16',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ),
              const SizedBox(height: 16),

              // ── Save button ─────────────────────────────────
              GradientButton(
                label: _saving ? 'Menyimpan...' : 'Mulai Main',
                icon: Icons.play_arrow_rounded,
                gradient: AppColors.primaryGradient,
                isLoading: _saving,
                onPressed: (_saving || _uploading) ? null : _save,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Avatar preview widget ────────────────────────────────

  Widget _buildAvatarPreview() {
    // Upload-only: show uploaded photo or initial-letter fallback
    if (_uploadedAvatarUrl != null) {
      final api = ref.read(apiServiceProvider);
      return Image.network(
        api.buildAvatarUrl(_uploadedAvatarUrl!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _initialAvatar(),
      );
    }
    if (_customPhoto != null) {
      return Image.file(_customPhoto!, fit: BoxFit.cover);
    }
    return _initialAvatar();
  }

  Widget _initialAvatar() {
    final name = _nameController.text.trim();
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final colors = [
      const Color(0xFF7B2FBE), const Color(0xFF4361EE),
      const Color(0xFFFF6B35), const Color(0xFF06D6A0),
    ];
    final color = colors[initial.codeUnits.first % colors.length];
    return Container(
      color: color,
      child: Center(
        child: Text(initial,
          style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
