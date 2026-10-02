import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';

/// Typing in a reference to follow an application without an account.
///
/// For the people who applied on the website before the app existed, and for
/// anybody who would rather not create an account at all.
class CareersTrackScreen extends ConsumerStatefulWidget {
  const CareersTrackScreen({super.key});

  @override
  ConsumerState<CareersTrackScreen> createState() => _CareersTrackScreenState();
}

class _CareersTrackScreenState extends ConsumerState<CareersTrackScreen> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _go() {
    final code = _code.text.trim().toUpperCase();

    if (code.length < 6) {
      setState(() => _error = 'A reference is 12 characters. Check what you have typed.');
      return;
    }

    setState(() => _error = null);
    context.push('/careers/track/$code');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Track an application'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 34),
        children: [
          const Icon(Icons.my_location, size: 42, color: AppColors.primary),
          const SizedBox(height: 16),
          const Center(
            child: Text('Enter your reference',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'It was shown to you after you applied, and is in your confirmation email.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            textAlign: TextAlign.center,
            maxLength: 16,
            autocorrect: false,
            onSubmitted: (_) => _go(),
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: 4),
            decoration: InputDecoration(
              hintText: 'XXXXXXXXXXXX',
              counterText: '',
              filled: true,
              fillColor: Colors.white,
              errorText: _error,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(13)),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _go,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
            child: const Text('Check my application', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 22),
          const Center(
            child: Text(
              'Lost your reference? Reply to your confirmation email and we will look it up.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
