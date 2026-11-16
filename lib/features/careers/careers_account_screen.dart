import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/careers_provider.dart';
import '../../core/services/careers_api.dart';
import '../../core/services/text_safe.dart';

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
                      initial(seeker.name),
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

          // -- Deleting the account ---------------------------------------
          //
          // App Store guideline 5.1.1(v): an app that lets somebody create an
          // account must let them delete it from inside the app. It sits here,
          // under Sign out, because this is the screen somebody opens when
          // they want to be done with the app - not buried in a web page.
          const SizedBox(height: 30),
          const Divider(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 18),
          const Text('Delete account',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          const SizedBox(height: 6),
          const Text(
            'Close this account and remove your details from Mastermind. '
            'This cannot be undone.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.45),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _confirmDelete(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              alignment: Alignment.centerLeft,
            ),
            icon: const Icon(Icons.delete_forever_rounded, size: 19),
            label: const Text('Delete my account',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final deleted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _DeleteAccountSheet(),
    );

    if (deleted == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
      context.go('/careers');
    }
  }
}

/// The confirmation, and the only place the account is actually deleted.
///
/// It says what will happen before it asks for anything, and asks for the
/// password rather than a typed "DELETE": a password is something only the
/// account holder has, which is the thing worth checking on a phone somebody
/// else may be holding.
class _DeleteAccountSheet extends ConsumerStatefulWidget {
  const _DeleteAccountSheet();

  @override
  ConsumerState<_DeleteAccountSheet> createState() => _DeleteAccountSheetState();
}

class _DeleteAccountSheetState extends ConsumerState<_DeleteAccountSheet> {
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _deleting = false;
  String? _error;
  List<String> _terms = const [];
  bool _loadingTerms = true;

  /// The fallback wording, used when the terms call fails. The sheet must be
  /// able to tell somebody what deletion does even with a flaky connection -
  /// refusing to explain is not an option on a screen like this.
  static const _fallbackTerms = [
    'Your sign-in, profile and job alerts are deleted immediately.',
    'Your CV and every other document you uploaded is deleted.',
    'Applications you already sent stay with the employer as part of their '
        'hiring record, but your name and contact details are removed from them.',
    'This cannot be undone. To apply again you would create a new account.',
  ];

  @override
  void initState() {
    super.initState();
    _loadTerms();
  }

  Future<void> _loadTerms() async {
    try {
      final data = await CareersApi.deletionTerms();
      final list = (data['summary'] as List?)?.map((e) => e.toString()).toList();
      if (!mounted) return;
      setState(() {
        _terms = list == null || list.isEmpty ? _fallbackTerms : list;
        _loadingTerms = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _terms = _fallbackTerms;
        _loadingTerms = false;
      });
    }
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Enter your password to confirm.');
      return;
    }

    setState(() {
      _deleting = true;
      _error = null;
    });

    try {
      await ref.read(careersProvider.notifier).deleteAccount(_passwordCtrl.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 18,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.delete_forever_rounded,
                    color: AppColors.error, size: 22),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Delete your account',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_loadingTerms)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              )
            else
              ..._terms.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6, right: 9),
                          child: Icon(Icons.circle, size: 5, color: AppColors.textMuted),
                        ),
                        Expanded(
                          child: Text(t,
                              style: const TextStyle(
                                  fontSize: 12.5, height: 1.45,
                                  color: AppColors.textSecondary)),
                        ),
                      ],
                    ),
                  )),
            const SizedBox(height: 10),
            const Text('Enter your password to confirm',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordCtrl,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                hintText: 'Password',
                errorText: _error,
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _deleting ? null : _delete,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size.fromHeight(48),
              ),
              child: _deleting
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Delete my account permanently',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _deleting ? null : () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              child: const Text('Keep my account'),
            ),
          ],
        ),
      ),
    );
  }
}
