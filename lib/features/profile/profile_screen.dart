import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/api_service.dart';
import '../../core/constants/api_constants.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _savingProfile = false;
  bool _savingPassword = false;
  bool _uploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    if (user != null) {
      _nameCtrl.text = user.name;
      _emailCtrl.text = user.email;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final initials = user.name.split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    final isMobile = MediaQuery.of(context).size.width < 700;

    final avatarCard = Container(
      width: isMobile ? double.infinity : 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              _uploadingAvatar
                  ? const CircleAvatar(
                      radius: 52,
                      backgroundColor: AppColors.infoLight,
                      child: CircularProgressIndicator(),
                    )
                  : user.avatarUrl != null
                      ? CircleAvatar(
                          radius: 52,
                          backgroundImage: NetworkImage(user.avatarUrl!),
                        )
                      : CircleAvatar(
                          radius: 52,
                          backgroundColor: AppColors.primary,
                          child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                        ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(user.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 4),
          Text(user.email, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: user.roles.map((r) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(12)),
              child: Text(r, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
            )).toList(),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          if (user.employee != null) ...[
            _InfoRow(icon: Icons.badge_rounded, label: user.employee!.empNumber),
            _InfoRow(icon: Icons.corporate_fare_rounded, label: user.employee!.department ?? '-'),
            _InfoRow(icon: Icons.work_rounded, label: user.employee!.designation ?? '-'),
          ],
          _InfoRow(
            icon: Icons.shield_rounded,
            label: user.mfaEnabled ? 'MFA Enabled' : 'MFA Disabled',
            color: user.mfaEnabled ? AppColors.success : AppColors.textMuted,
          ),
        ],
      ),
    );

    final formsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FormCard(
          title: 'Personal Information',
          subtitle: 'Update your name and email address',
          child: Column(
            children: [
              isMobile
                  ? Column(children: [
                      TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_rounded, size: 18, color: AppColors.textSecondary))),
                      const SizedBox(height: 12),
                      TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_rounded, size: 18, color: AppColors.textSecondary))),
                    ])
                  : Row(children: [
                      Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_rounded, size: 18, color: AppColors.textSecondary)))),
                      const SizedBox(width: 16),
                      Expanded(child: TextField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_rounded, size: 18, color: AppColors.textSecondary)))),
                    ]),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _savingProfile ? null : _saveProfile,
                  child: _savingProfile
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _FormCard(
          title: 'Change Password',
          subtitle: 'Make sure your account is using a strong password',
          child: Column(
            children: [
              TextField(
                controller: _oldPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password', prefixIcon: Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 12),
              isMobile
                  ? Column(children: [
                      TextField(controller: _newPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock_rounded, size: 18, color: AppColors.textSecondary))),
                      const SizedBox(height: 12),
                      TextField(controller: _confirmPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm Password', prefixIcon: Icon(Icons.lock_rounded, size: 18, color: AppColors.textSecondary))),
                    ])
                  : Row(children: [
                      Expanded(child: TextField(controller: _newPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New Password', prefixIcon: Icon(Icons.lock_rounded, size: 18, color: AppColors.textSecondary)))),
                      const SizedBox(width: 16),
                      Expanded(child: TextField(controller: _confirmPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm Password', prefixIcon: Icon(Icons.lock_rounded, size: 18, color: AppColors.textSecondary)))),
                    ]),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: _savingPassword ? null : _savePassword,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                  child: _savingPassword
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Update Password'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _FormCard(
          title: 'Account Security',
          subtitle: 'Manage your session and account settings',
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(authProvider.notifier).logout(); // GoRouter handles redirect
                },
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatarCard,
                const SizedBox(height: 20),
                formsColumn,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                avatarCard,
                const SizedBox(width: 24),
                Expanded(child: formsColumn),
              ],
            ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final formData = FormData.fromMap({
        'avatar': await MultipartFile.fromFile(file.path!, filename: file.name),
      });
      await ApiService.postForm(ApiConstants.profileAvatar, formData);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    try {
      await ApiService.put(ApiConstants.profile, data: {
        'name': _nameCtrl.text,
        'email': _emailCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated'), backgroundColor: AppColors.success));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _savePassword() async {
    if (_newPassCtrl.text != _confirmPassCtrl.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _savingPassword = true);
    try {
      await ApiService.put(ApiConstants.profilePassword, data: {
        'current_password': _oldPassCtrl.text,
        'password': _newPassCtrl.text,
        'password_confirmation': _confirmPassCtrl.text,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated'), backgroundColor: AppColors.success));
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoRow({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: color ?? AppColors.textSecondary))),
        ],
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _FormCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
