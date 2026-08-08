import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

/// Inventory item model
class InventoryItem {
  final String id;
  final String name;
  final String emoji;
  final String category; // gift, curse, item, other
  final int quantity;
  final String rarity; // common, rare, epic, legendary

  const InventoryItem({
    required this.id,
    required this.name,
    required this.emoji,
    required this.category,
    required this.quantity,
    this.rarity = 'common',
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    emoji: json['emoji'] as String? ?? '📦',
    category: json['category'] as String? ?? 'item',
    quantity: (json['quantity'] as num?)?.toInt() ?? 1,
    rarity: json['rarity'] as String? ?? 'common',
  );
}

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});
  @override
  ConsumerState<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends ConsumerState<InventoryPage> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<InventoryItem> _items = [];
  bool _loading = true;
  String _selectedTab = 'all';

  static const _tabs = ['Semua', 'Gift', 'Curse', 'Item', 'Lainnya'];
  static const _tabKeys = ['all', 'gift', 'curse', 'item', 'other'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _selectedTab = _tabKeys[_tabCtrl.index]);
      }
    });
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.getInventory();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isSuccess && res.data != null) {
        final list = res.data!['items'] as List<dynamic>? ?? [];
        _items = list.map((e) => InventoryItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    });
  }

  List<InventoryItem> get _filteredItems {
    if (_selectedTab == 'all') return _items;
    return _items.where((i) => i.category == _selectedTab).toList();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              IconButton(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
              ),
              const SizedBox(width: 8),
              const Text('Inventory', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
              const Spacer(),
              // Notification bell
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFFDAA520), size: 22),
              ),
            ]),
          ),
          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1F2E),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFDAA520).withOpacity( 0.2)),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)]),
                borderRadius: BorderRadius.circular(6),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textMuted,
              dividerHeight: 0,
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),
          const SizedBox(height: 12),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFDAA520)))
                : _filteredItems.isEmpty
                    ? _emptyState()
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: _filteredItems.length,
                        itemBuilder: (_, i) => _InventoryCard(item: _filteredItems[i]),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.inventory_2_outlined, color: Colors.white.withOpacity( 0.2), size: 48),
      const SizedBox(height: 12),
      const Text('Belum ada item', style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
      const SizedBox(height: 4),
      const Text('Beli item di Toko untuk mengisi inventory', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
    ]),
  );
}

class _InventoryCard extends StatelessWidget {
  final InventoryItem item;
  const _InventoryCard({required this.item});

  Color get _borderColor => switch (item.rarity) {
    'legendary' => const Color(0xFFDAA520),
    'epic' => const Color(0xFF9C27B0),
    'rare' => const Color(0xFF2196F3),
    _ => const Color(0xFF3D4450),
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFF1A1F2E),
        border: Border.all(color: _borderColor.withOpacity( 0.5), width: 1.5),
      ),
      child: Stack(children: [
        // Content
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Text(item.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
            ),
            const Spacer(),
          ],
        ),
        // Quantity badge (top-right)
        if (item.quantity > 1)
          Positioned(
            top: 4, right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: Colors.black.withOpacity( 0.7),
                border: Border.all(color: const Color(0xFFDAA520).withOpacity( 0.5)),
              ),
              child: Text('x${item.quantity}', style: const TextStyle(color: Color(0xFFDAA520), fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
        // Lock icon for locked items (quantity = 0)
        if (item.quantity == 0)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.black.withOpacity( 0.6),
              ),
              child: const Center(child: Icon(Icons.lock_rounded, color: Color(0xFF4A5060), size: 20)),
            ),
          ),
      ]),
    );
  }
}
