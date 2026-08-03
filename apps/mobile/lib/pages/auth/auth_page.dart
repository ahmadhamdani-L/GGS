import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animCtrl;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  // #4 FIX: Separate _obscure state per form so toggling visibility in Login
  // doesn't accidentally expose password in Register form and vice versa.
  bool _obscureLogin = true;
  bool _obscureRegister = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final notifier = ref.read(authProvider.notifier);
    await notifier.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (ref.read(authProvider).isAuthenticated) context.go('/home');
  }

  Future<void> _register() async {
    final notifier = ref.read(authProvider.notifier);
    await notifier.register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
    if (!mounted) return;
    if (ref.read(authProvider).isAuthenticated) context.go('/profile/setup');
  }

  Future<void> _guest() async {
    final notifier = ref.read(authProvider.notifier);
    await notifier.loginAsGuest();
    if (!mounted) return;
    if (ref.read(authProvider).isAuthenticated) context.go('/profile/setup');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Image.asset(
            'assets/login-bg.png',
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF080D1A), Color(0xFF1E1B4B), Color(0xFF080D1A)],
                ),
              ),
            ),
          ),
          // Dark overlay with gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      SizedBox(height: size.height * 0.02),
                  // Logo
                  _buildLogo(),
                  const SizedBox(height: 16),
                  // Glass card with form
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2E).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            // Tab bar
                            _buildTabBar(),
                            const SizedBox(height: 24),
                            // Error
                            if (auth.error != null) _buildError(auth.error!),
                            // Forms
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: MediaQuery.of(context).size.height * 0.28,
                                minHeight: 200,
                              ),
                              child: TabBarView(
                                controller: _tabController,
                                children: [_loginForm(auth), _registerForm(auth)],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Divider
                  _buildDivider(),
                  const SizedBox(height: 12),
                  // Guest button
                  _buildGuestButton(auth),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // GGS Logo with chibi
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520)]),
            boxShadow: [
              BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: const Center(child: Text('🐺', style: TextStyle(fontSize: 42))),
        ),
        const SizedBox(height: 14),
        const Text(
          'GGS',
          style: TextStyle(
            color: Color(0xFFDAA520),
            fontSize: 36,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            shadows: [Shadow(color: Color(0xFFDAA520), blurRadius: 20)],
          ),
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.4)),
            color: const Color(0xFFDAA520).withValues(alpha: 0.08),
          ),
          child: const Text(
            'WEREWOLF ONLINE',
            style: TextStyle(color: Color(0xFFDAA520), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDAA520).withValues(alpha: 0.2)),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)]),
          borderRadius: BorderRadius.circular(10),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMuted,
        dividerHeight: 0,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: const [Tab(text: 'Masuk'), Tab(text: 'Daftar')],
      ),
    );
  }

  Widget _buildError(String error) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(error, style: const TextStyle(color: AppColors.error, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 0.5, color: Colors.white.withValues(alpha: 0.1))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('atau', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 12)),
        ),
        Expanded(child: Container(height: 0.5, color: Colors.white.withValues(alpha: 0.1))),
      ],
    );
  }

  Widget _buildGuestButton(AuthState auth) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: auth.isLoading ? null : _guest,
        icon: const Icon(Icons.person_outline_rounded, size: 18),
        label: const Text('Main sebagai Tamu', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDAA520),
          side: BorderSide(color: const Color(0xFFDAA520).withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _loginForm(AuthState auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Selamat datang kembali,\nWolves! 🐺', style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 14),
        _input(_emailController, 'Email / Username', Icons.person_outline,
            keyboard: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _inputObscure(_passwordController, 'Password', Icons.lock_outline,
            obscure: _obscureLogin,
            onToggle: () => setState(() => _obscureLogin = !_obscureLogin)),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _showForgotPasswordDialog(context),
            child: const Text('Lupa password?',
                style: TextStyle(color: Color(0xFFDAA520), fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 8),
        // Golden Login button
        GestureDetector(
          onTap: auth.isLoading ? null : _login,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)]),
              border: Border.all(color: const Color(0xFFDAA520)),
              boxShadow: [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.3), blurRadius: 8)],
            ),
            child: Center(child: auth.isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Login', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
          ),
        ),
        const SizedBox(height: 12),
        // Social login (coming soon)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('atau lanjut dengan', style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.7), fontSize: 10)),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _socialButton('G', 'Google'),
          const SizedBox(width: 10),
          _socialButton('f', 'Facebook'),
          const SizedBox(width: 10),
          _socialButton('', 'Apple'),
        ]),
      ],
    );
  }

  Widget _socialButton(String icon, String label) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Segera hadir!'), backgroundColor: AppColors.warning, behavior: SnackBarBehavior.floating, duration: Duration(seconds: 1)),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Text('🔜', style: const TextStyle(fontSize: 8)),
        ]),
      ),
    );
  }

  // #3 FIX: Forgot-password is now a true two-step flow.
  // Step 1: user enters email → server sends/returns a 6-digit token.
  // Step 2: user enters that token + new password → server validates and resets.
  void _showForgotPasswordDialog(BuildContext context) {
    final emailCtrl = TextEditingController(text: _emailController.text.trim());
    final tokenCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    bool isSubmitting = false;
    bool step2 = false; // false = step1 (email), true = step2 (token + new pass)
    String? devToken; // shown in dev mode only

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.surfaceElevated,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(children: [
              const Icon(Icons.lock_reset_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                step2 ? 'Masukkan Kode Reset' : 'Lupa Password',
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
            ]),
            content: step2
                // ── Step 2 ──────────────────────────────────────────────
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.check_circle_outline, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          devToken != null
                              ? 'Kode reset (dev): $devToken'
                              : 'Kode 6 digit telah dikirim ke email ${emailCtrl.text.trim()}.',
                          style: TextStyle(
                            color: devToken != null ? AppColors.warning : AppColors.success,
                            fontSize: 12,
                          ),
                        )),
                      ]),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: tokenCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8),
                      decoration: InputDecoration(
                        hintText: '000000',
                        hintStyle: TextStyle(
                            color: AppColors.textMuted.withValues(alpha: 0.4),
                            fontSize: 22,
                            letterSpacing: 8),
                        labelText: 'Kode 6 Digit',
                        prefixIcon: const Icon(Icons.pin_outlined, size: 18),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPassCtrl,
                      obscureText: true,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Password Baru (min 8, huruf besar & angka)',
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => setDialogState(() { step2 = false; tokenCtrl.clear(); newPassCtrl.clear(); }),
                      child: const Text('← Kirim ulang kode',
                          style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ])
                // ── Step 1 ──────────────────────────────────────────────
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    const Text(
                      'Masukkan email terdaftar. Kode verifikasi akan dikirim untuk mereset password.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined, size: 18),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ]),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final api = ref.read(apiServiceProvider);

                        if (!step2) {
                          // Step 1: request token
                          final email = emailCtrl.text.trim();
                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Email wajib diisi'),
                                backgroundColor: AppColors.warning));
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          final resp = await api.forgotPassword(email: email);
                          if (!ctx.mounted) return;
                          setDialogState(() => isSubmitting = false);
                          if (resp.isSuccess) {
                            // In dev mode server returns token directly
                            devToken = resp.data?['token'] as String?;
                            setDialogState(() => step2 = true);
                          } else {
                            // Always show generic message to prevent email enumeration
                            setDialogState(() => step2 = true);
                          }
                        } else {
                          // Step 2: submit token + new password
                          final token = tokenCtrl.text.trim();
                          final newPass = newPassCtrl.text;
                          if (token.length != 6) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Masukkan kode 6 digit'),
                                backgroundColor: AppColors.warning));
                            return;
                          }
                          if (newPass.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Password baru wajib diisi'),
                                backgroundColor: AppColors.warning));
                            return;
                          }
                          setDialogState(() => isSubmitting = true);
                          final resp = await api.forgotPassword(
                              email: emailCtrl.text.trim(),
                              token: token,
                              newPassword: newPass);
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (!mounted) return;
                          if (resp.isSuccess) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Password berhasil diubah! Silakan login.'),
                                backgroundColor: AppColors.success));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(resp.error ?? 'Kode tidak valid atau sudah kadaluarsa'),
                                backgroundColor: AppColors.error));
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(step2 ? 'Reset Password' : 'Kirim Kode'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _registerForm(AuthState auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Buat akun baru,\nBergabunglah dengan Wolves!', style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        _input(_nameController, 'Username', Icons.person_outline),
        const SizedBox(height: 10),
        _input(_emailController, 'Email', Icons.email_outlined,
            keyboard: TextInputType.emailAddress),
        const SizedBox(height: 10),
        _inputObscure(
            _passwordController,
            'Password',
            Icons.lock_outline,
            obscure: _obscureRegister,
            onToggle: () => setState(() => _obscureRegister = !_obscureRegister)),
        const SizedBox(height: 14),
        // Golden Daftar button
        GestureDetector(
          onTap: auth.isLoading ? null : _register,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: const LinearGradient(colors: [Color(0xFFB8860B), Color(0xFFDAA520), Color(0xFFB8860B)]),
              border: Border.all(color: const Color(0xFFDAA520)),
              boxShadow: [BoxShadow(color: const Color(0xFFDAA520).withValues(alpha: 0.3), blurRadius: 8)],
            ),
            child: Center(child: auth.isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Daftar', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800))),
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text('Dengan mendaftar, kamu setuju dengan\nSyarat & Ketentuan dan Kebijakan Privasi',
          style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.5), fontSize: 9), textAlign: TextAlign.center)),
      ],
    );
  }

  /// Plain text input (no visibility toggle).
  Widget _input(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFDAA520).withValues(alpha: 0.7), size: 20),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.3),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: const Color(0xFFDAA520).withValues(alpha: 0.3))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: const Color(0xFFDAA520).withValues(alpha: 0.3))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDAA520), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  /// Password input with its own visibility toggle (no shared state).
  Widget _inputObscure(TextEditingController ctrl, String label, IconData icon,
      {required bool obscure, required VoidCallback onToggle}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.6), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFDAA520).withValues(alpha: 0.7), size: 20),
        suffixIcon: IconButton(
          icon: Icon(
              obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textMuted, size: 20),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.3),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: const Color(0xFFDAA520).withValues(alpha: 0.3))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: const Color(0xFFDAA520).withValues(alpha: 0.3))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFDAA520), width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}
