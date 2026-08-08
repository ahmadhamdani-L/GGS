import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';

/// Diamond top-up page — shows available packages and opens Midtrans Snap for payment.
class DiamondTopUpPage extends ConsumerStatefulWidget {
  const DiamondTopUpPage({super.key});
  @override
  ConsumerState<DiamondTopUpPage> createState() => _DiamondTopUpPageState();
}

class _DiamondTopUpPageState extends ConsumerState<DiamondTopUpPage> {
  List<Map<String, dynamic>> _packages = [];
  bool _loading = true;
  bool _purchasing = false;

  @override
  void initState() {
    super.initState();
    _loadPackages();
  }

  Future<void> _loadPackages() async {
    final api = ref.read(apiServiceProvider);
    final res = await api.getPaymentPackages();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.isSuccess && res.data != null) {
        _packages = List<Map<String, dynamic>>.from(res.data!['packages'] as List? ?? []);
        // Sort by price ascending
        _packages.sort((a, b) => (a['price'] as int).compareTo(b['price'] as int));
      }
    });
  }

  Future<void> _purchase(Map<String, dynamic> pkg) async {
    if (_purchasing) return;
    setState(() => _purchasing = true);
    HapticFeedback.heavyImpact();

    final api = ref.read(apiServiceProvider);
    final res = await api.createPaymentOrder(pkg['id'] as String);

    if (!mounted) return;
    setState(() => _purchasing = false);

    if (res.isSuccess && res.data != null) {
      final redirectUrl = res.data!['redirectUrl'] as String?;
      if (redirectUrl != null && redirectUrl.isNotEmpty) {
        // Open Midtrans Snap payment page in external browser
        final uri = Uri.parse(redirectUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          // After user returns from payment, refresh diamond balance
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) ref.read(socialProvider.notifier).refreshDiamonds();
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Tidak bisa membuka halaman pembayaran'),
              backgroundColor: AppColors.error));
          }
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res.error ?? 'Gagal membuat pesanan'),
          backgroundColor: AppColors.error));
      }
    }
  }

  String _formatPrice(int price) {
    // Format as Indonesian Rupiah
    final s = price.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp ${buf.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(diamondBalanceProvider);
    final diamonds = balance?.amount ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: Column(children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
              onPressed: () => Navigator.pop(context)),
            const SizedBox(width: 8),
            const Text('Top Up Diamond', style: TextStyle(
              color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF7B2FBE), Color(0xFF4FC3F7)]),
                borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('💎', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text('$diamonds', style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
          ]),
        ),

        // Banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1a0533), Color(0xFF2d1b69)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF7B2FBE).withOpacity( 0.3)),
          ),
          child: Row(children: [
            const Text('💎', style: TextStyle(fontSize: 36)),
            const SizedBox(width: 14),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Diamond', style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              SizedBox(height: 2),
              Text('Gunakan untuk mengirim Gift, membeli item eksklusif, dan lainnya.',
                style: TextStyle(color: Colors.white60, fontSize: 11)),
            ])),
          ]),
        ),

        // Packages grid
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _packages.isEmpty
                  ? const Center(child: Text('Tidak ada paket tersedia',
                      style: TextStyle(color: AppColors.textMuted)))
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
                        childAspectRatio: 0.85),
                      itemCount: _packages.length,
                      itemBuilder: (_, i) => _PackageCard(
                        pkg: _packages[i],
                        formatPrice: _formatPrice,
                        onTap: () => _purchase(_packages[i]),
                        purchasing: _purchasing,
                      ),
                    ),
        ),

        // Footer note
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Pembayaran diproses oleh Midtrans. Diamond langsung masuk setelah pembayaran berhasil.',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
      ])),
    );
  }
}

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> pkg;
  final String Function(int) formatPrice;
  final VoidCallback onTap;
  final bool purchasing;
  const _PackageCard({
    required this.pkg, required this.formatPrice, required this.onTap, required this.purchasing});

  bool get _isPopular => pkg['id'] == 'diamond_500' || pkg['id'] == 'diamond_1000';
  bool get _isBest    => pkg['id'] == 'diamond_5000';

  @override
  Widget build(BuildContext context) {
    final diamonds = pkg['diamonds'] as int? ?? 0;
    final price    = pkg['price'] as int? ?? 0;
    final name     = pkg['name'] as String? ?? '';

    return GestureDetector(
      onTap: purchasing ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity( 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isBest
                ? const Color(0xFFFFD700).withOpacity( 0.5)
                : _isPopular
                    ? AppColors.primary.withOpacity( 0.4)
                    : Colors.white.withOpacity( 0.08),
            width: _isBest || _isPopular ? 2 : 1),
          boxShadow: _isBest
              ? [BoxShadow(color: const Color(0xFFFFD700).withOpacity( 0.15), blurRadius: 12)]
              : null,
        ),
        child: Stack(children: [
          // Badge
          if (_isPopular || _isBest)
            Positioned(top: 0, right: 0, child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _isBest ? const Color(0xFFFFD700) : AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14), bottomLeft: Radius.circular(10))),
              child: Text(_isBest ? 'BEST' : 'POPULER',
                style: TextStyle(
                  color: _isBest ? Colors.black : Colors.white,
                  fontSize: 8, fontWeight: FontWeight.w900)),
            )),
          // Content
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('💎', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text('$diamonds', style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
              Text(name, style: const TextStyle(
                color: AppColors.textMuted, fontSize: 10),
                maxLines: 1, overflow: TextOverflow.ellipsis),
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: _isBest
                      ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFF8C00)])
                      : AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10)),
                child: Text(
                  formatPrice(price),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isBest ? Colors.black : Colors.white,
                    fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
