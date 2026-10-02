import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/careers_provider.dart';

/// Creating a careers account.
///
/// The categories are asked for here rather than later, because that is the
/// thing that makes the account worth having: pick the kinds of work you do,
/// and a new vacancy in one of them reaches you without you looking.
class CareersRegisterScreen extends ConsumerStatefulWidget {
  const CareersRegisterScreen({super.key});

  @override
  ConsumerState<CareersRegisterScreen> createState() => _CareersRegisterScreenState();
}

class _CareersRegisterScreenState extends ConsumerState<CareersRegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  String? _education;
  int? _experience;
  final Set<int> _categories = {};

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  static const _educationLevels = [
    'Primary',
    'O Level',
    'A Level',
    'Certificate',
    'Diploma',
    'Bachelor degree',
    'Masters degree',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(careersProvider.notifier).loadCategories();
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _location, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(careersProvider.notifier).register({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'password': _password.text,
        'password_confirmation': _confirm.text,
        'location': _location.text.trim().isEmpty ? null : _location.text.trim(),
        'education_level': _education,
        'experience_years': _experience,
        'categories': _categories.toList(),
      });

      if (!mounted) return;
      context.go('/careers');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. You can now apply for any position.')),
      );
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
    final categories = ref.watch(careersProvider).categories;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Create account'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 34),
          children: [
            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12.5)),
              ),
            _field(_name, 'Full name', required: true, icon: Icons.person_outline),
            _field(_email, 'Email address',
                required: true,
                icon: Icons.mail_outline,
                keyboard: TextInputType.emailAddress,
                validator: (v) =>
                    (v ?? '').contains('@') ? null : 'Enter a valid email address'),
            _field(_phone, 'Phone number',
                icon: Icons.phone_outlined,
                keyboard: TextInputType.phone,
                hint: '0772 123456'),
            _field(_location, 'Where you live', icon: Icons.place_outlined, hint: 'Kampala'),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _education,
              decoration: _decoration('Highest level of education', Icons.school_outlined),
              items: _educationLevels
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() => _education = v),
            ),
            const SizedBox(height: 13),
            DropdownButtonFormField<int>(
              initialValue: _experience,
              decoration: _decoration('Years of experience', Icons.work_history_outlined),
              items: [0, 1, 2, 3, 5, 7, 10, 15, 20]
                  .map((y) => DropdownMenuItem(
                        value: y,
                        child: Text(y == 0
                            ? 'No experience yet'
                            : '$y ${y == 1 ? "year" : "years"} or more'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _experience = v),
            ),
            const SizedBox(height: 20),
            const Text('What kind of work are you looking for?',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            const SizedBox(height: 3),
            const Text('Pick as many as apply. We will tell you when a job opens in one of them.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4)),
            const SizedBox(height: 10),
            if (categories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text('Loading categories...',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              )
            else
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: categories.map((c) {
                  final on = _categories.contains(c.id);
                  return FilterChip(
                    label: Text(c.name, style: const TextStyle(fontSize: 12.5)),
                    selected: on,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: AppColors.inputBorder),
                    labelStyle: TextStyle(color: on ? Colors.white : AppColors.textSecondary),
                    onSelected: (_) => setState(() {
                      if (on) {
                        _categories.remove(c.id);
                      } else {
                        _categories.add(c.id);
                      }
                    }),
                  );
                }).toList(),
              ),
            const SizedBox(height: 22),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              decoration: _decoration('Password', Icons.lock_outline).copyWith(
                helperText: 'At least 8 characters',
                suffixIcon: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v ?? '').length >= 8 ? null : 'Use at least 8 characters',
            ),
            const SizedBox(height: 13),
            TextFormField(
              controller: _confirm,
              obscureText: _obscure,
              decoration: _decoration('Confirm password', Icons.lock_outline),
              validator: (v) => v == _password.text ? null : 'The two passwords do not match',
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
                  : const Text('Create account', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
            Center(
              child: TextButton(
                onPressed: _busy ? null : () => context.push('/careers/sign-in'),
                child: const Text('I already have an account'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = false,
    IconData? icon,
    String? hint,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        decoration: _decoration(label, icon ?? Icons.edit_outlined).copyWith(hintText: hint),
        validator: validator ??
            (required ? (v) => (v ?? '').trim().isEmpty ? '$label is required' : null : null),
      ),
    );
  }
}
