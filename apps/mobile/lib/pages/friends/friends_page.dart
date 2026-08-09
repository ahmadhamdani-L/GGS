import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class FriendsPage extends ConsumerStatefulWidget {
  const FriendsPage({super.key});

  @override
  ConsumerState<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends ConsumerState<FriendsPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _loading = true;
  bool _actionLoading = false;
  String? _error;
  List<dynamic> _friends = [];
  List<dynamic> _pending = [];
  List<dynamic> _recent = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final friendsResp = await api.getFriends();
      final recentResp = await api.getRecentPlayers();

      if (!mounted) return;

      if (!friendsResp.isSuccess) {
        setState(() {
          _loading = false;
          _error = friendsResp.error ?? 'Gagal memuat daftar teman';
        });
        return;
      }

      setState(() {
        _friends = friendsResp.data?['friends'] as List<dynamic>? ?? [];
        _pending = friendsResp.data?['pending'] as List<dynamic>? ?? [];
        _recent = recentResp.data?['players'] as List<dynamic>? ?? [];
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Terjadi kesalahan: $e';
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                ),
                const SizedBox(width: 8),
                const Text('Sosial', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
                const Spacer(),
                // Refresh button
                IconButton(
                  onPressed: _loading ? null : _loadData,
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDAA520)),
                        )
                      : const Icon(Icons.refresh_rounded, color: AppColors.textMuted, size: 22),
                ),
              ]),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari teman (nama atau ID)...',
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted, size: 20),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                onSubmitted: (query) => _searchUser(query),
              ),
            ),
            // Tabs
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 42,
              decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(10)),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)]), borderRadius: BorderRadius.circular(8)),
                labelColor: AppColors.background,
                unselectedLabelColor: AppColors.textMuted,
                dividerHeight: 0,
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                tabs: [
                  Tab(text: 'Teman (${_friends.length})'),
                  Tab(text: 'Permintaan (${_pending.length})'),
                  const Tab(text: 'Recent'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Loading overlay for actions
            if (_actionLoading)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFDAA520))),
                    SizedBox(width: 8),
                    Text('Memproses...', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFDAA520)));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadData,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDAA520)),
              ),
            ],
          ),
        ),
      );
    }

    return TabBarView(
      controller: _tabCtrl,
      children: [
        _buildFriendsList(),
        _buildPendingList(),
        _buildRecentList(),
      ],
    );
  }

  Widget _buildFriendsList() {
    if (_friends.isEmpty) {
      return _emptyState('Belum ada teman', 'Tambahkan teman dari tab Recent Players');
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFDAA520),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _friends.length,
        itemBuilder: (_, i) {
          final f = _friends[i] as Map<String, dynamic>;
          return _playerTile(f, actions: [
            _actionBtn(Icons.mail_rounded, AppColors.blueTeam, 'Undang', () => _inviteFriend(f)),
            _actionBtn(Icons.person_remove_rounded, AppColors.error, 'Hapus', () => _removeFriend(f['userId'])),
          ]);
        },
      ),
    );
  }

  Widget _buildPendingList() {
    if (_pending.isEmpty) {
      return _emptyState('Tidak ada permintaan', 'Permintaan pertemanan akan muncul di sini');
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFDAA520),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _pending.length,
        itemBuilder: (_, i) {
          final p = _pending[i] as Map<String, dynamic>;
          return _playerTile(p, actions: [
            _actionBtn(Icons.check_circle_rounded, AppColors.success, 'Terima', () => _acceptRequest(p['userId'])),
            _actionBtn(Icons.close_rounded, AppColors.error, 'Tolak', () => _rejectRequest(p['userId'])),
          ]);
        },
      ),
    );
  }

  Widget _buildRecentList() {
    if (_recent.isEmpty) {
      return _emptyState('Belum ada riwayat', 'Main game untuk melihat pemain lain');
    }
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFDAA520),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _recent.length,
        itemBuilder: (_, i) {
          final p = _recent[i] as Map<String, dynamic>;
          final isFriend = p['isFriend'] == true;
          return _playerTile(p, actions: [
            if (!isFriend) _actionBtn(Icons.person_add_rounded, const Color(0xFFDAA520), 'Tambah', () => _addFriend(p['userId'])),
            _actionBtn(Icons.flag_rounded, AppColors.warning, 'Report', () => _showReportDialog(p['userId'])),
          ]);
        },
      ),
    );
  }

  Widget _playerTile(Map<String, dynamic> p, {List<Widget> actions = const []}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Image.asset(
                AppConstants.avatarPath(p['avatarId'] as int? ?? 1),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 20),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              p['displayName'] ?? '???',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              'Lv.${p['level'] ?? 1}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ]),
        ),
        ...actions,
      ]),
    );
  }

  Widget _actionBtn(IconData icon, Color color, String tooltip, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: _actionLoading ? null : onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: _actionLoading ? color.withValues(alpha: 0.05) : color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: _actionLoading ? color.withValues(alpha: 0.3) : color, size: 16),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.people_outline_rounded, color: AppColors.textMuted.withValues(alpha: 0.3), size: 48),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      ]),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _addFriend(String friendId) async {
    setState(() => _actionLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.postFriendAction(friendId, 'add');

      if (!mounted) return;

      if (resp.isSuccess) {
        _showSnackBar('Permintaan pertemanan terkirim!');
        await _loadData();
      } else {
        _showSnackBar(resp.error ?? 'Gagal mengirim permintaan', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _acceptRequest(String friendId) async {
    setState(() => _actionLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.postFriendAction(friendId, 'accept');

      if (!mounted) return;

      if (resp.isSuccess) {
        _showSnackBar('Permintaan diterima!');
        await _loadData();
      } else {
        _showSnackBar(resp.error ?? 'Gagal menerima permintaan', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _rejectRequest(String friendId) async {
    setState(() => _actionLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.postFriendAction(friendId, 'remove');

      if (!mounted) return;

      if (resp.isSuccess) {
        _showSnackBar('Permintaan ditolak');
        await _loadData();
      } else {
        _showSnackBar(resp.error ?? 'Gagal menolak permintaan', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  Future<void> _removeFriend(String friendId) async {
    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Teman?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
          'Anda yakin ingin menghapus teman ini?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _actionLoading = true);

    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.postFriendAction(friendId, 'remove');

      if (!mounted) return;

      if (resp.isSuccess) {
        _showSnackBar('Teman dihapus');
        await _loadData();
      } else {
        _showSnackBar(resp.error ?? 'Gagal menghapus teman', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _actionLoading = false);
    }
  }

  void _inviteFriend(Map<String, dynamic> friend) {
    _showSnackBar('Fitur undang game akan segera hadir!');
  }

  void _searchUser(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;

    setState(() => _actionLoading = true);
    final api = ref.read(apiServiceProvider);
    final resp = await api.searchUsers(q);
    // #14 FIX: check mounted after async gap before both setState and showDialog.
    if (!mounted) return;
    setState(() => _actionLoading = false);

    final rawList = resp.isSuccess && resp.data?['users'] != null
        ? (resp.data!['users'] as List)
        : [];
    final matches = rawList.map((e) => e as Map<String, dynamic>).toList();

    // Second mounted check before showDialog (setState above is fine, but
    // showDialog also requires a valid BuildContext).
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Hasil Pencarian DB: "$query"',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (matches.isNotEmpty) ...[
                ...matches.map((p) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFDAA520),
                        child: Icon(Icons.person, color: Colors.white, size: 18),
                      ),
                      title: Text(p['displayName'] as String? ?? 'Pemain', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('✨ ${p['charm'] ?? 300} | ❤️ ${p['popularity'] ?? 150} | Lv.${p['level'] ?? 1}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDAA520), padding: const EdgeInsets.symmetric(horizontal: 10)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _addFriend(p['userId'] as String? ?? p['id'] as String);
                        },
                        child: const Text('+ Teman', style: TextStyle(fontSize: 11)),
                      ),
                    )),
              ] else ...[
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('Pemain tidak ditemukan di database.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(String userId) {
    showDialog(context: context, builder: (_) => _ReportDialog(userId: userId));
  }
}

class _ReportDialog extends ConsumerStatefulWidget {
  final String userId;
  const _ReportDialog({required this.userId});

  @override
  ConsumerState<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<_ReportDialog> {
  String _reason = 'harassment';
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Laporkan Pemain',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          value: _reason,
          dropdownColor: AppColors.surfaceElevated,
          decoration: const InputDecoration(labelText: 'Alasan'),
          items: const [
            DropdownMenuItem(value: 'harassment', child: Text('Harassment')),
            DropdownMenuItem(value: 'cheating', child: Text('Cheating')),
            DropdownMenuItem(value: 'spam', child: Text('Spam')),
            DropdownMenuItem(value: 'offensive', child: Text('Offensive')),
            DropdownMenuItem(value: 'other', child: Text('Lainnya')),
          ],
          onChanged: _submitting ? null : (v) => setState(() => _reason = v ?? 'harassment'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _detailsCtrl,
          maxLines: 3,
          maxLength: 500,
          enabled: !_submitting,
          decoration: const InputDecoration(
            hintText: 'Detail (opsional)',
            counterStyle: TextStyle(color: AppColors.textMuted),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
        ],
      ]),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: Text(
            'Batal',
            style: TextStyle(color: _submitting ? AppColors.textMuted : AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submitReport,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Kirim'),
        ),
      ],
    );
  }

  Future<void> _submitReport() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.reportPlayer(widget.userId, _reason, _detailsCtrl.text);

      if (!mounted) return;

      if (resp.isSuccess) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan berhasil dikirim'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        setState(() {
          _error = resp.error ?? 'Gagal mengirim laporan';
          _submitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Terjadi kesalahan: $e';
        _submitting = false;
      });
    }
  }
}
