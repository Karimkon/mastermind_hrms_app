import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/careers_provider.dart';

/// A job seeker's own details, and the categories they follow.
///
/// Changing the categories here is the whole point of the screen: it is how
/// somebody says "tell me about driving jobs now, not cleaning".
class CareersAccountScreen extends ConsumerStatefulWidget {
  const CareersAccountScreen({super.key});

  @override
  ConsumerState<CareersAccountScreen> createState() => _CareersAccountScreenState();
}

class _CareersAccountScreenState extends ConsumerState<CareersAccountScreen> {
  Set<int>? _categories;
  bool? _notifyEmail;
  bool? _notifySms;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(careersProvider.notifier).loadCategories();
    });
  }

  Future<void> _save() async {
    final seeker = ref.read(careersProvider).seeker;
    if (seeker == null) return;

    setState(() => _saving = true);

    try {
      await ref.read(careersProvider.notifier).updateProfile({
        'categories': (_categories ?? seeker.categories.map((c) => c.id).toSet()).toList(),
        'notify_email': _notifyEmail ?? seeker.notifyEmail,
        'notify_sms': _notifySms ?? seeker.notifySms,
      });

      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(careersProvider);
    final seeker = state.seeker;

    if (seeker == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My account')),
        body: Center(
          child: FilledButton(
            onPressed: () => context.go('/careers/sign-in'),
            child: const Text('Sign in'),
          ),
        ),
      );
    }

    final selected = _categories ?? seeker.categories.map((c) => c.id).toSet();
    final notifyEmail = _notifyEmail ?? seeker.notifyEmail;
    final notifySms = _notifySms ?? seeker.notifySms;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My account'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 34),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      seeker.name.isEmpty ? '?' : seeker.name[0].toUpperCase(),
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(seeker.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(seeker.email,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      if ((seeker.phone ?? '').isNotEmpty)
                        Text(seeker.phone!,
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            tileColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.cardBorder),
            ),
            leading: const Icon(Icons.folder_shared_outlined),
            title: const Text('My applications', style: TextStyle(fontSize: 14)),
            subtitle: Text(
              '${seeker.applications} ${seeker.applications == 1 ? "application" : "applications"}',
              style: const TextStyle(fontSize: 12),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/careers/applications'),
          ),
          const SizedBox(height: 18),
          const Text('Jobs you want to hear about',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          const SizedBox(height: 3),
          const Text('We will tell you when a vacancy opens in one of these.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 11),
          if (state.categories.isEmpty)
            const Text('Loading...', style: TextStyle(fontSize: 12, color: AppColors.textMuted))
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: state.categories.map((c) {
                final on = selected.contains(c.id);
                return FilterChip(
                  label: Text(c.name, style: const TextStyle(fontSize: 12.5)),
                  selected: on,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: AppColors.inputBorder),
                  labelStyle: TextStyle(color: on ? Colors.white : AppColors.textSecondary),
                  onSelected: (_) => setState(() {
                    final next = {...selected};
                    if (on) {
                      next.remove(c.id);
                    } else {
                      next.add(c.id);
                    }
                    _categories = next;
                  }),
                );
              }).toList(),
            ),
          const SizedBox(height: 18),
          const Text('How we reach you',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          const SizedBox(height: 8),
          SwitchListTile(
            value: notifyEmail,
            onChanged: (v) => setState(() => _notifyEmail = v),
            title: const Text('Email', style: TextStyle(fontSize: 14)),
            subtitle: const Text('New vacancies in your categories',
                style: TextStyle(fontSize: 12)),
            contentPadding: EdgeInsets.zero,
          ),
          SwitchListTile(
            value: notifySms,
            onChanged: (v) => setState(() => _notifySms = v),
            title: const Text('SMS', style: TextStyle(fontSize: 14)),
            subtitle: const Text('A short text when a job opens',
                style: TextStyle(fontSize: 12)),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 6),
          const Text(
            'Updates about an application you have already made are always sent, '
            'whatever you choose here.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.45),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _saving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save changes', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 26),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(careersProvider.notifier).signOut();
              if (context.mounted) context.go('/careers');
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.errorLight),
              padding: const EdgeInsets.symmetric(vertical: 13),
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}
