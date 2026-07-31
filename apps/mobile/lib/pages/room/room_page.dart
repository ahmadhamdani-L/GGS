import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chibi_provider.dart';
import '../../providers/room_provider.dart';
import '../../widgets/chibi_avatar.dart';

class RoomPage extends ConsumerStatefulWidget {
  const RoomPage({super.key});

  @override
  ConsumerState<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends ConsumerState<RoomPage> {
  bool _hasNavigated = false;
  int? _selectedRoom;
  final _joinCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch public rooms when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(roomProvider.notifier).fetchPublicRooms();
    });
  }

  @override
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider);
    final chibiConfig = ref.watch(chibiProvider);

    // Navigate when room is joined
    if (room.room != null && !_hasNavigated) {
      _hasNavigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/lobby/${room.room!.code}');
      });
    }
    if (room.room == null) _hasNavigated = false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F1629), Color(0xFF080D1A)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white.withValues(alpha: 0.06),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary, size: 20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Main Bareng',
                          style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                      // Player chibi mini
                      Container(
                        width: 36,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5), width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: ChibiAvatar(
                            config: chibiConfig,
                            size: 40,
                            animate: false,
                            showShadow: false,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Loading indicator
                if (room.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: LinearProgressIndicator(color: AppColors.primary, backgroundColor: AppColors.surfaceElevated),
                  ),

                // Error
                if (room.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.error.withValues(alpha: 0.1),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(room.error!, style: const TextStyle(color: AppColors.error, fontSize: 12))),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 8),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // MABAR SECTION
                        _buildSectionHeader('🎮 Main Bareng Teman', 'Buat atau gabung room privat'),
                        const SizedBox(height: 12),
                        
                        // Create Private Room Button
                        _MabarCard(
                          icon: Icons.add_circle_rounded,
                          iconColor: AppColors.success,
                          title: 'Buat Room Privat',
                          subtitle: 'Ajak teman dengan kode room',
                          onTap: () => _showCreateRoomDialog(),
                        ),
                        const SizedBox(height: 10),
                        
                        // Join with Code Button
                        _MabarCard(
                          icon: Icons.login_rounded,
                          iconColor: AppColors.blueTeam,
                          title: 'Gabung dengan Kode',
                          subtitle: 'Masukkan kode room teman',
                          onTap: () => _showJoinCodeDialog(),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // PUBLIC ROOMS SECTION
                        _buildSectionHeader('🌐 Room Publik', 'Main dengan pemain lain'),
                        const SizedBox(height: 12),
                        
                        // Loading indicator for public rooms
                        if (room.isLoadingPublicRooms)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                            ),
                          )
                        else if (room.publicRooms.isEmpty)
                          // Show default 10 empty rooms if no data yet
                          ...List.generate(10, (index) {
                            final roomNumber = index + 1;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RoomCard(
                                roomNumber: roomNumber,
                                playerCount: 0,
                                isFull: false,
                                isSelected: _selectedRoom == roomNumber,
                                onTap: () {
                                  setState(() => _selectedRoom = roomNumber);
                                  _showJoinOptions(roomNumber);
                                },
                              ),
                            );
                          })
                        else
                          // Show real public rooms data
                          ...room.publicRooms.asMap().entries.map((entry) {
                            final index = entry.key;
                            final pubRoom = entry.value;
                            final roomNumber = index + 1;
                            final isFull = pubRoom.playerCount >= pubRoom.maxPlayers;
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _RoomCard(
                                roomNumber: roomNumber,
                                playerCount: pubRoom.playerCount,
                                isFull: isFull,
                                isSelected: _selectedRoom == roomNumber,
                                hostName: pubRoom.hostName,
                                status: pubRoom.status,
                                onTap: isFull ? null : () {
                                  setState(() => _selectedRoom = roomNumber);
                                  _showJoinOptions(roomNumber);
                                },
                              ),
                            );
                          }),
                        
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ],
    );
  }

  void _showCreateRoomDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _CreateRoomSheet(
        onConfirm: (maxPlayers) {
          Navigator.pop(ctx);
          _createPrivateRoom(maxPlayers);
        },
      ),
    );
  }

  void _createPrivateRoom(int maxPlayers) {
    final auth = ref.read(authProvider);
    if (auth.userId == null) return;
    HapticFeedback.mediumImpact();
    ref.read(roomProvider.notifier).createRoom(
      auth.userId!,
      maxPlayers: maxPlayers,
      displayName: auth.profile?.displayName,
      avatarId: auth.profile?.avatarId,
    );
  }

  void _showJoinCodeDialog() {
    _joinCodeController.clear();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _JoinCodeSheet(
          controller: _joinCodeController,
          onJoin: () {
            final code = _joinCodeController.text.trim().toUpperCase();
            if (code.length >= 4) {
              Navigator.pop(ctx);
              _joinRoomWithCode(code);
            }
          },
        ),
      ),
    );
  }

  void _joinRoomWithCode(String code) {
    final auth = ref.read(authProvider);
    if (auth.userId == null) return;
    HapticFeedback.mediumImpact();
    ref.read(roomProvider.notifier).joinRoom(auth.userId!, code);
  }

  void _showJoinOptions(int roomNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _JoinOptionsSheet(
        roomNumber: roomNumber,
        onJoinRandom: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(ctx);
          _joinRoom(roomNumber, randomSeat: true);
        },
        onPickSeat: () {
          HapticFeedback.mediumImpact();
          Navigator.pop(ctx);
          _joinRoom(roomNumber, randomSeat: false);
        },
      ),
    );
  }

  void _joinRoom(int roomNumber, {required bool randomSeat}) {
    final auth = ref.read(authProvider);
    if (auth.userId == null) return;
    
    // Room Publik: use room code format "PUB{roomNumber}" for public rooms
    final publicRoomCode = 'PUB$roomNumber';
    
    if (randomSeat) {
      // Quick play - try to join, server will create if doesn't exist
      ref.read(roomProvider.notifier).joinRoom(auth.userId!, publicRoomCode);
    } else {
      // Pick seat - join lobby first
      ref.read(roomProvider.notifier).joinRoom(auth.userId!, publicRoomCode);
    }
  }
}

// ─── Mabar Card ─────────────────────────────────────────────
class _MabarCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MabarCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: iconColor.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: iconColor.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.textMuted.withValues(alpha: 0.5), size: 24),
          ],
        ),
      ),
    );
  }
}

// ─── Room Card ──────────────────────────────────────────────
class _RoomCard extends StatelessWidget {
  final int roomNumber;
  final int playerCount;
  final bool isFull;
  final bool isSelected;
  final VoidCallback? onTap;
  final String? hostName;
  final String? status;

  const _RoomCard({
    required this.roomNumber,
    required this.playerCount,
    required this.isFull,
    this.isSelected = false,
    this.onTap,
    this.hostName,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isPlaying = status == 'playing';
    final borderColor = isSelected
        ? AppColors.primary
        : (isFull || isPlaying ? AppColors.error.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08));

    return GestureDetector(
      onTap: (isFull || isPlaying) ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
            ),
            child: Row(
              children: [
                // Room icon
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: (isFull || isPlaying)
                        ? AppColors.error.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Text(
                      '$roomNumber',
                      style: TextStyle(
                        color: (isFull || isPlaying) ? AppColors.error : AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Room info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room $roomNumber',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.people_rounded,
                            size: 14,
                            color: (isFull || isPlaying) ? AppColors.error : AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$playerCount/16',
                            style: TextStyle(
                              color: (isFull || isPlaying) ? AppColors.error : AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (hostName != null && hostName!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.star_rounded, size: 12, color: AppColors.primaryLight.withValues(alpha: 0.7)),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                hostName!,
                                style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.8), fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: _getStatusColor().withValues(alpha: 0.1),
                  ),
                  child: Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    if (status == 'playing') return AppColors.warning;
    if (isFull) return AppColors.error;
    if (playerCount > 0) return AppColors.blueTeam;
    return AppColors.success;
  }

  String _getStatusText() {
    if (status == 'playing') return 'Main';
    if (isFull) return 'Penuh';
    if (playerCount > 0) return 'Lobby';
    return 'Buka';
  }
}

// ─── Join Options Bottom Sheet ──────────────────────────────
class _JoinOptionsSheet extends StatelessWidget {
  final int roomNumber;
  final VoidCallback onJoinRandom;
  final VoidCallback onPickSeat;

  const _JoinOptionsSheet({
    required this.roomNumber,
    required this.onJoinRandom,
    required this.onPickSeat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Text(
            'Masuk Room $roomNumber',
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Pilih cara bergabung',
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          // Join Random button
          GestureDetector(
            onTap: onJoinRandom,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: AppColors.primaryGradient,
                boxShadow: [
                  BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shuffle_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Join Random',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Duduk di kursi acak yang tersedia',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 16),
          // Pick Seat button
          GestureDetector(
            onTap: onPickSeat,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: AppColors.blueGradient,
                boxShadow: [
                  BoxShadow(color: AppColors.blueTeam.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.event_seat_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Pilih Kursi',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Masuk lobby dan pilih tempat duduk sendiri',
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Create Room Sheet ──────────────────────────────────────
class _CreateRoomSheet extends StatefulWidget {
  final void Function(int maxPlayers) onConfirm;

  const _CreateRoomSheet({required this.onConfirm});

  @override
  State<_CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<_CreateRoomSheet> {
  int _maxPlayers = 12;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.groups_rounded, color: AppColors.success, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Buat Room Mabar', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Room privat untuk main bareng teman', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Jumlah Pemain', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    Text('$_maxPlayers pemain', style: const TextStyle(color: AppColors.primary, fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _playerCountChip(8),
                    const SizedBox(width: 8),
                    _playerCountChip(10),
                    const SizedBox(width: 8),
                    _playerCountChip(12),
                    const SizedBox(width: 8),
                    _playerCountChip(16),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('Min 8 pemain untuk mulai game', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 11)),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Buat Room',
            icon: Icons.rocket_launch_rounded,
            gradient: const LinearGradient(colors: [Color(0xFF059669), Color(0xFF10B981)]),
            onPressed: () => widget.onConfirm(_maxPlayers),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _playerCountChip(int count) {
    final isSelected = _maxPlayers == count;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _maxPlayers = count),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: isSelected ? AppColors.primary.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
            border: Border.all(color: isSelected ? AppColors.primary : Colors.white.withValues(alpha: 0.1)),
          ),
          child: Center(
            child: Text(
              '$count',
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Join Code Sheet ────────────────────────────────────────
class _JoinCodeSheet extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onJoin;

  const _JoinCodeSheet({required this.controller, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              color: Colors.white.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.blueTeam.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.qr_code_rounded, color: AppColors.blueTeam, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('Gabung Room', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Masukkan kode room dari teman', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: 'ABCD',
              hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.3), fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 8),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.04),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.blueTeam, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
            inputFormatters: [
              LengthLimitingTextInputFormatter(6),
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
            ],
            onSubmitted: (_) => onJoin(),
          ),
          const SizedBox(height: 24),
          GradientButton(
            label: 'Gabung',
            icon: Icons.login_rounded,
            gradient: AppColors.blueGradient,
            onPressed: onJoin,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
