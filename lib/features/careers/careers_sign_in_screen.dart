import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/careers_provider.dart';

/// Signing in to a careers account.
///
/// Separate from the staff login on purpose. Two different populations, two
/// different tables, and nothing good comes of one form trying to guess which
/// kind of person is typing into it.
class CareersSignInScreen extends ConsumerStatefulWidget {
  const CareersSignInScreen({super.key});

  @override
  ConsumerState<CareersSignInScreen> createState() => _CareersSignInScreenState();
}

class _CareersSignInScreenState extends ConsumerState<CareersSignInScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(careersProvider.notifier).signIn(_email.text.trim(), _password.text);
      if (!mounted) return;
      context.go('/careers');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Sign in'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 26, 20, 34),
          children: [
            const Text('Welcome back',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            const Text('Sign in to follow your applications and apply for new positions.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 22),
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12.5)),
              ),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email address',
                prefixIcon: const Icon(Icons.mail_outline, size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => (v ?? '').contains('@') ? null : 'Enter your email address',
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline, size: 20),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Sign in', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => context.push('/careers/register'),
                child: const Text('I do not have an account yet'),
              ),
            ),
            const Divider(height: 36),
            Center(
              child: TextButton.icon(
                onPressed: () => context.go('/login'),
                icon: const Icon(Icons.badge_outlined, size: 17),
                label: const Text('Mastermind staff login'),
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
