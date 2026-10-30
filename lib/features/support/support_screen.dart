import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/support_info.dart';

/// Help and contact details.
///
/// Exists because App Review Guideline 1.5 (Safety: Developer Information)
/// requires a user to be able to reach the developer easily, and version
/// 1.5.3 was rejected with no support screen, no contact address and no
/// privacy link anywhere in the app.
///
/// Reachable WITHOUT signing in, from the first screen the app opens on.
/// Putting it behind the login would hide it from the one person most likely
/// to need it.
///
/// Every detail can be copied rather than tapped to launch Mail or the
/// dialler. That is deliberate: launching needs url_launcher, a new native
/// dependency whose iOS build could not be verified from this machine, and
/// adding build risk in the middle of a rejection cycle is a poor trade for
/// saving one tap.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  late Future<SupportInfo> _info;

  @override
  void initState() {
    super.initState();
    _info = SupportInfo.load();
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));

    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('$label copied'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Help and Support'),
        elevation: 0,
      ),
      body: FutureBuilder<SupportInfo>(
        future: _info,
        builder: (context, snapshot) {
          // Never a spinner that can hang and never an error state: load()
          // falls back to what shipped in the binary rather than throwing.
          final info = snapshot.data ?? SupportInfo.fallback;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Intro(company: info.company),
              const SizedBox(height: 20),

              const _SectionLabel('Contact us'),
              const SizedBox(height: 8),

              if (info.email != null)
                _ContactTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: info.email!,
                  onTap: () => _copy('Email address', info.email!),
                ),

              if (info.phone != null)
                _ContactTile(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: info.phone!,
                  onTap: () => _copy('Phone number', info.phone!),
                ),

              if (info.careersEmail != null)
                _ContactTile(
                  icon: Icons.work_outline_rounded,
                  label: 'Recruitment enquiries',
                  value: info.careersEmail!,
                  onTap: () => _copy('Email address', info.careersEmail!),
                ),

              _ContactTile(
                icon: Icons.language_rounded,
                label: 'Website',
                value: info.website,
                onTap: () => _copy('Website address', info.website),
              ),

              if (info.address != null)
                _ContactTile(
                  icon: Icons.location_on_outlined,
                  label: 'Office',
                  value: info.address!,
                  onTap: () => _copy('Address', info.address!),
                ),

              const SizedBox(height: 20),
              const _SectionLabel('When we are open'),
              const SizedBox(height: 8),
              _InfoCard(child: Text(
                info.hours,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              )),

              const SizedBox(height: 20),
              const _SectionLabel('Your privacy'),
              const SizedBox(height: 8),
              _InfoCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text(
                    'This app records attendance at work sites, which means it '
                    'collects your location at the moment you clock in or out. '
                    'It is used to confirm you were at the site and for nothing '
                    'else, and it is never collected while the app is closed.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => _copy('Privacy policy address', '${info.website}/privacy'),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        const Icon(Icons.privacy_tip_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          '${info.website}/privacy',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        )),
                        const Icon(Icons.copy_rounded, size: 14, color: AppColors.textSecondary),
                      ]),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 20),
              const _SectionLabel('About this app'),
              const SizedBox(height: 8),
              const _InfoCard(child: Text(
                'Mastermind HRMS\nVersion 1.5.3',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              )),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  final String company;
  const _Intro({required this.company});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            company,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Having trouble, or need to reach somebody? Use any of the details '
            'below and we will get back to you. Tap any detail to copy it.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      );
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: AppColors.textSecondary,
        ),
      );
}

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: child,
      );
}

class _ContactTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _ContactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    )),
                    const SizedBox(height: 2),
                    // Selectable as well as copyable: a reviewer reading the
                    // screen should never have to transcribe by eye.
                    SelectableText(value, style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                  ]),
                ),
                const Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
              ]),
            ),
          ),
        ),
      );
}
