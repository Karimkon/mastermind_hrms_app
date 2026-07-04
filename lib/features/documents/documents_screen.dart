import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/document_model.dart';
import '../../core/providers/documents_provider.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // NOK form controllers
  final _nokNameCtrl = TextEditingController();
  final _nokRelationCtrl = TextEditingController();
  final _nokPhoneCtrl = TextEditingController();
  final _nokEmailCtrl = TextEditingController();
  final _passportCtrl = TextEditingController();
  bool _nokSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nokNameCtrl.dispose();
    _nokRelationCtrl.dispose();
    _nokPhoneCtrl.dispose();
    _nokEmailCtrl.dispose();
    _passportCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'My Documents',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'Manage your personal documents and next of kin information.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(text: 'Documents'),
                  Tab(text: 'Next of Kin'),
                ],
              ),
            ],
          ),
        ),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _DocumentsTab(ref: ref),
              _NokTab(
                nokNameCtrl: _nokNameCtrl,
                nokRelationCtrl: _nokRelationCtrl,
                nokPhoneCtrl: _nokPhoneCtrl,
                nokEmailCtrl: _nokEmailCtrl,
                passportCtrl: _passportCtrl,
                saving: _nokSaving,
                onSave: _saveNok,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveNok() async {
    setState(() => _nokSaving = true);
    try {
      await ref.read(documentsActionsProvider.notifier).updateNok(
            nextOfKinName: _nokNameCtrl.text.trim().isEmpty ? null : _nokNameCtrl.text.trim(),
            nextOfKinRelation: _nokRelationCtrl.text.trim().isEmpty ? null : _nokRelationCtrl.text.trim(),
            nextOfKinPhone: _nokPhoneCtrl.text.trim().isEmpty ? null : _nokPhoneCtrl.text.trim(),
            nextOfKinEmail: _nokEmailCtrl.text.trim().isEmpty ? null : _nokEmailCtrl.text.trim(),
            passportNumber: _passportCtrl.text.trim().isEmpty ? null : _passportCtrl.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _nokSaving = false);
    }
  }
}

// ─────────────── DOCUMENTS TAB ───────────────
class _DocumentsTab extends StatelessWidget {
  final WidgetRef ref;
  const _DocumentsTab({required this.ref});

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Uploaded Documents', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ElevatedButton.icon(
                onPressed: () => _showUploadDialog(context),
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: const Text('Upload Document'),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          docsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(48), child: CircularProgressIndicator())),
            error: (e, _) => _ErrorCard(e.toString()),
            data: (docs) => docs.isEmpty
                ? const _EmptyState()
                : Column(children: docs.map((d) => _DocumentCard(doc: d, ref: ref)).toList()),
          ),
        ],
      ),
    );
  }

  void _showUploadDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _UploadDialog(ref: ref),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(60),
        child: Column(
          children: [
            Icon(Icons.folder_open_rounded, size: 52, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text('No documents uploaded yet', style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
            SizedBox(height: 4),
            Text('Upload your CV, ID, certificates and more.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DocumentModel doc;
  final WidgetRef ref;
  const _DocumentCard({required this.doc, required this.ref});

  @override
  Widget build(BuildContext context) {
    final typeColor = _typeColor(doc.documentType);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          // Type badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _typeLabel(doc.documentType),
              style: TextStyle(color: typeColor, fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                if (doc.fileName != null)
                  Text(doc.fileName!, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                if (doc.expiryDate != null)
                  Row(children: [
                    const Icon(Icons.event_rounded, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text('Expires: ${doc.expiryDate}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ]),
              ],
            ),
          ),
          Text(doc.createdAt ?? '', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
            onPressed: () => _confirmDelete(context, doc),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, DocumentModel doc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Document'),
        content: Text('Delete "${doc.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(documentsActionsProvider.notifier).deleteDocument(doc.id);
                ref.invalidate(documentsProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    const map = {
      'cv': 'CV',
      'id': 'ID',
      'passport': 'Passport',
      'academic': 'Academic',
      'certificate': 'Certificate',
      'contract': 'Contract',
      'other': 'Other',
    };
    return map[type.toLowerCase()] ?? type.toUpperCase();
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'cv':         return AppColors.primary;
      case 'id':         return AppColors.success;
      case 'passport':   return const Color(0xFF8B5CF6);
      case 'academic':   return AppColors.info;
      case 'certificate':return AppColors.warning;
      case 'contract':   return const Color(0xFFEC4899);
      default:           return AppColors.textSecondary;
    }
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.errorLight, borderRadius: BorderRadius.circular(8)),
      child: Text(message, style: const TextStyle(color: AppColors.error)),
    );
  }
}

// ─────────────── UPLOAD DIALOG ───────────────
class _UploadDialog extends ConsumerStatefulWidget {
  final WidgetRef ref;
  const _UploadDialog({required this.ref});

  @override
  ConsumerState<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends ConsumerState<_UploadDialog> {
  String _docType = 'cv';
  final _titleCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  PlatformFile? _pickedFile;
  bool _uploading = false;

  final List<String> _docTypes = ['cv', 'id', 'passport', 'academic', 'certificate', 'contract', 'other'];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _expiryCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Upload Document'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document type
              const Text('Document Type *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _docType,
                decoration: const InputDecoration(isDense: true),
                items: _docTypes.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t[0].toUpperCase() + t.substring(1)),
                )).toList(),
                onChanged: (v) => setState(() => _docType = v ?? 'cv'),
              ),
              const SizedBox(height: 12),

              // Title
              const Text('Title (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _titleCtrl, decoration: const InputDecoration(hintText: 'Leave blank to use file name', isDense: true)),
              const SizedBox(height: 12),

              // Expiry date
              const Text('Expiry Date (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _expiryCtrl, decoration: const InputDecoration(hintText: 'YYYY-MM-DD', isDense: true)),
              const SizedBox(height: 12),

              // Notes
              const Text('Notes (optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(controller: _notesCtrl, maxLines: 2, decoration: const InputDecoration(isDense: true)),
              const SizedBox(height: 16),

              // File picker
              GestureDetector(
                onTap: _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: _pickedFile != null ? AppColors.success : AppColors.cardBorder, style: BorderStyle.solid),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _pickedFile != null ? Icons.check_circle_rounded : Icons.attach_file_rounded,
                        color: _pickedFile != null ? AppColors.success : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        _pickedFile?.name ?? 'Tap to choose a file',
                        style: TextStyle(
                          color: _pickedFile != null ? AppColors.textPrimary : AppColors.textSecondary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _uploading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _uploading || _pickedFile == null ? null : _upload,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          child: _uploading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Upload'),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false, withReadStream: false);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _pickedFile = result.files.first);
    }
  }

  Future<void> _upload() async {
    if (_pickedFile == null || _pickedFile!.path == null) return;
    setState(() => _uploading = true);
    try {
      await ref.read(documentsActionsProvider.notifier).uploadDocument(
            filePath: _pickedFile!.path!,
            fileName: _pickedFile!.name,
            documentType: _docType,
            title: _titleCtrl.text.trim(),
            expiryDate: _expiryCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
          );
      widget.ref.invalidate(documentsProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}

// ─────────────── NOK TAB ───────────────
class _NokTab extends StatelessWidget {
  final TextEditingController nokNameCtrl;
  final TextEditingController nokRelationCtrl;
  final TextEditingController nokPhoneCtrl;
  final TextEditingController nokEmailCtrl;
  final TextEditingController passportCtrl;
  final bool saving;
  final VoidCallback onSave;

  const _NokTab({
    required this.nokNameCtrl,
    required this.nokRelationCtrl,
    required this.nokPhoneCtrl,
    required this.nokEmailCtrl,
    required this.passportCtrl,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // NOK section
          _SectionCard(
            title: 'Next of Kin',
            subtitle: 'Emergency contact information',
            icon: Icons.people_alt_rounded,
            children: [
              _FormRow(children: [
                _Field(label: 'Full Name', controller: nokNameCtrl, hint: 'Jane Doe'),
                _Field(label: 'Relationship', controller: nokRelationCtrl, hint: 'Spouse, Parent, Sibling...'),
              ]),
              _FormRow(children: [
                _Field(label: 'Phone Number', controller: nokPhoneCtrl, hint: '+27 xx xxx xxxx', keyboardType: TextInputType.phone),
                _Field(label: 'Email Address', controller: nokEmailCtrl, hint: 'jane@example.com', keyboardType: TextInputType.emailAddress),
              ]),
            ],
          ),
          const SizedBox(height: 16),

          // Passport section
          _SectionCard(
            title: 'Travel Documents',
            subtitle: 'Passport and travel document numbers',
            icon: Icons.flight_rounded,
            children: [
              _FormRow(children: [
                _Field(label: 'Passport Number', controller: passportCtrl, hint: 'A1234567'),
                const Expanded(child: SizedBox()),
              ]),
            ],
          ),
          const SizedBox(height: 24),

          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded, size: 16),
              label: Text(saving ? 'Saving...' : 'Save Changes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.infoLight, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _FormRow extends StatelessWidget {
  final List<Widget> children;
  const _FormRow({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children.expand((w) sync* {
          yield w;
          if (w != children.last) yield const SizedBox(width: 16);
        }).toList(),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            decoration: InputDecoration(hintText: hint, isDense: true),
          ),
        ],
      ),
    );
  }
}
