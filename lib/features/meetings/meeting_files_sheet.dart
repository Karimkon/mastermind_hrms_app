import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';

/// The papers for a meeting, and a way to read them on the phone.
///
/// The files are not public URLs — they sit on the server's private disk and
/// are served by a controller that checks the caller was actually invited. So
/// they cannot simply be handed to a browser: they are fetched through the
/// authenticated client, written to the app's own cache, and opened with
/// whatever the device uses for that type.
///
/// The server decides what appears here. Somebody who is not part of the
/// meeting gets an empty list, not a list they cannot open — the names alone
/// would say more than they should.
class MeetingFilesSheet extends StatefulWidget {
  final int meetingId;
  final String meetingTitle;

  const MeetingFilesSheet({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
  });

  static Future<void> show(BuildContext context, int meetingId, String title) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          MeetingFilesSheet(meetingId: meetingId, meetingTitle: title),
    );
  }

  @override
  State<MeetingFilesSheet> createState() => _MeetingFilesSheetState();
}

class _MeetingFilesSheetState extends State<MeetingFilesSheet> {
  List<dynamic>? _files;
  String? _error;

  /// File id -> 0.0..1.0 while it is coming down.
  final Map<int, double> _progress = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.get('/meetings/${widget.meetingId}');
      if (!mounted) return;
      setState(
        () => _files = (res.data['data']?['files'] as List?) ?? const [],
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not load the documents for this meeting.');
    }
  }

  Future<void> _open(Map<String, dynamic> file) async {
    final id = file['id'] as int;
    if (_progress.containsKey(id)) return; // already on its way

    setState(() => _progress[id] = 0);

    try {
      final dir = await getTemporaryDirectory();
      // Namespaced by meeting so two meetings with an "agenda.pdf" do not
      // overwrite each other in the cache.
      final folder = Directory('${dir.path}/meetings/${widget.meetingId}');
      await folder.create(recursive: true);
      final path = '${folder.path}/${file['name']}';

      await ApiService.dio.download(
        '/meetings/${widget.meetingId}/files/$id',
        path,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress[id] = received / total);
          }
        },
      );

      if (!mounted) return;
      setState(() => _progress.remove(id));

      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Downloaded, but nothing on this phone opens ${file['name']}.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _progress.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is DioException && e.response?.statusCode == 403
                ? 'You are not part of this meeting.'
                : 'That document could not be downloaded.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  IconData _iconFor(String? mime, String name) {
    final n = name.toLowerCase();
    if (n.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (n.endsWith('.xlsx') || n.endsWith('.xls') || n.endsWith('.csv')) {
      return Icons.table_chart_rounded;
    }
    if (n.endsWith('.doc') || n.endsWith('.docx')) {
      return Icons.description_rounded;
    }
    if (n.endsWith('.ppt') || n.endsWith('.pptx')) {
      return Icons.slideshow_rounded;
    }
    if ((mime ?? '').startsWith('image/')) return Icons.image_rounded;
    if ((mime ?? '').startsWith('video/')) return Icons.movie_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.attach_file_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.meetingTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error),
                ),
              )
            else if (_files == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_files!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'No documents for this meeting.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _files!.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = Map<String, dynamic>.from(_files![i] as Map);
                    final id = f['id'] as int;
                    final busy = _progress.containsKey(id);

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _iconFor(
                          f['mime'] as String?,
                          f['name'] as String? ?? '',
                        ),
                        color: AppColors.primary,
                      ),
                      title: Text(
                        f['name'] as String? ?? 'Document',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: busy
                          ? Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: LinearProgressIndicator(
                                value: _progress[id] == 0
                                    ? null
                                    : _progress[id],
                                minHeight: 3,
                              ),
                            )
                          : Text(
                              [
                                f['readable_size'],
                                if (f['uploaded_by'] != null) f['uploaded_by'],
                              ].whereType<String>().join(' · '),
                              style: const TextStyle(fontSize: 11),
                            ),
                      trailing: busy
                          ? Text(
                              '${((_progress[id] ?? 0) * 100).round()}%',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : const Icon(
                              Icons.download_rounded,
                              size: 20,
                              color: AppColors.primary,
                            ),
                      onTap: busy ? null : () => _open(f),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
