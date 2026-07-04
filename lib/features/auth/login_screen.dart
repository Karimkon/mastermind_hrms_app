import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final mfaToken = await ref.read(authProvider.notifier).login(
        _emailCtrl.text.trim(),
        _passCtrl.text.trim(),
      );
      if (!mounted) return;
      if (mfaToken != null) {
        context.push('/mfa', extra: mfaToken);
      }
      // If null → router redirect handles navigation to /dashboard
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildMobileLoginForm() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Logo header
                    Image.asset('assets/images/logo.jpg', height: 56, fit: BoxFit.contain),
                    const SizedBox(height: 32),
                    const Text('Welcome back', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Sign in to your HRMS account', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                    const SizedBox(height: 28),
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.errorLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                        ]),
                      ),
                      const SizedBox(height: 20),
                    ],
                    const Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'you@mastermind.co.za',
                        prefixIcon: Icon(Icons.email_outlined, size: 18, color: AppColors.textSecondary),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email required';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                      onFieldSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 16),
                    const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textSecondary),
                        suffixIcon: GestureDetector(
                          onTap: () => setState(() => _obscure = !_obscure),
                          child: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: AppColors.textSecondary),
                        ),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Password required' : null,
                      onFieldSubmitted: (_) => _login(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: _buildMobileLoginForm(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          // Left branding panel
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F172A), Color(0xFF1E3A8A)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryLight],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Center(
                              child: Text('M', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24)),
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Mastermind', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                              Text('HRMS v2.0', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Headline
                      const Text(
                        'Manage Your\nEntire Workforce\n— All in One Place',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'A complete enterprise HR solution with 10 integrated\nmodules, 6 role-based access levels, automated payroll,\nand real-time attendance tracking.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 15, height: 1.6),
                      ),
                      const SizedBox(height: 48),
                      // Feature pills
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: const [
                          _FeaturePill(icon: Icons.fingerprint_rounded, label: 'Smart Attendance'),
                          _FeaturePill(icon: Icons.payments_rounded, label: 'Automated Payroll'),
                          _FeaturePill(icon: Icons.person_search_rounded, label: 'AI Recruitment'),
                          _FeaturePill(icon: Icons.bar_chart_rounded, label: 'Analytics'),
                          _FeaturePill(icon: Icons.security_rounded, label: '6 Role Levels'),
                          _FeaturePill(icon: Icons.notifications_active_rounded, label: 'Notifications'),
                        ],
                      ),
                      const Spacer(),
                      const Text(
                        'Mastermind Consultants Uganda',
                        style: TextStyle(color: Color(0xFF475569), fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Right login form
          Container(
            width: 460,
            color: Colors.white,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sign in to your HRMS account',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                        ),
                        const SizedBox(height: 36),

                        // Error banner
                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.error.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Email
                        const Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            hintText: 'you@mastermind.co.za',
                            prefixIcon: Icon(Icons.email_outlined, size: 18, color: AppColors.textSecondary),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Email required';
                            if (!v.contains('@')) return 'Invalid email';
                            return null;
                          },
                          onFieldSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 16),

                        // Password
                        const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _passCtrl,
                          obscureText: _obscure,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textSecondary),
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscure = !_obscure),
                              child: Icon(
                                _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Password required' : null,
                          onFieldSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 28),

                        // Sign in button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),

                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

