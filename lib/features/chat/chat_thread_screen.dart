import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/chat_model.dart';
import '../../core/providers/chat_provider.dart';
import '../../core/services/api_service.dart';

/// One conversation: what was said, and the means to say more.
class ChatThreadScreen extends ConsumerStatefulWidget {
  final int conversationId;
  final String? title;

  const ChatThreadScreen({super.key, required this.conversationId, this.title});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _draft = TextEditingController();
  final _scroll = ScrollController();
  final _recorder = AudioRecorder();

  bool _recording = false;
  bool _starting = false;
  int _seconds = 0;
  String? _recordPath;

  @override
  void dispose() {
    _draft.dispose();
    _scroll.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _sendText() async {
    final text = _draft.text.trim();
    if (text.isEmpty) return;

    _draft.clear();

    final ok = await ref
        .read(threadProvider(widget.conversationId).notifier)
        .send(widget.conversationId, body: text);

    if (ok) _scrollDown();
  }

  Future<void> _attach() async {
    final picked = await FilePicker.platform.pickFiles(withData: false);
    final path = picked?.files.single.path;
    if (path == null) return;

    // The server refuses nothing by type, only by size, and says so plainly
    // when it does - so anything the person picks is worth attempting.
    final ok = await ref
        .read(threadProvider(widget.conversationId).notifier)
        .send(widget.conversationId, file: File(path), body: _draft.text.trim());

    if (ok) {
      _draft.clear();
      _scrollDown();
    }
  }

  Future<void> _startRecording() async {
    if (_recording || _starting) return;

    setState(() => _starting = true);

    try {
      if (!await _recorder.hasPermission()) {
        _say('Microphone permission was refused. Allow it and try again.');
        return;
      }

      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}${Platform.pathSeparator}voice-${DateTime.now().millisecondsSinceEpoch}.m4a';

      // AAC in an MP4 container: playable everywhere, and small enough that a
      // long note still sends on a phone connection.
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);

      _recordPath = path;
      setState(() {
        _recording = true;
        _seconds = 0;
      });

      _tick();
    } catch (_) {
      _say('Could not start recording.');
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  /// One second at a time, so the banner counts up while recording.
  Future<void> _tick() async {
    while (mounted && _recording) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _recording) setState(() => _seconds++);
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    if (!_recording) return;

    final seconds = _seconds;
    setState(() => _recording = false);

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {
      _say('The recording could not be stopped cleanly.');
    }

    path ??= _recordPath;
    _recordPath = null;

    if (!send || path == null) return;

    final file = File(path);
    if (!file.existsSync() || await file.length() == 0) {
      _say('Nothing was recorded. Check the microphone is not muted.');
      return;
    }

    // The bytes of an M4A look the same whether they hold a voice note or a
    // film, so the server is told which this is.
    final ok = await ref.read(threadProvider(widget.conversationId).notifier).send(
          widget.conversationId,
          file: file,
          kind: 'audio',
          duration: seconds,
        );

    if (ok) _scrollDown();
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final thread = ref.watch(threadProvider(widget.conversationId));

    ref.listen(threadProvider(widget.conversationId), (_, next) {
      final error = next.valueOrNull?.error;
      if (error != null) {
        _say(error);
        ref.read(threadProvider(widget.conversationId).notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(thread.valueOrNull?.title.isNotEmpty == true
            ? thread.valueOrNull!.title
            : (widget.title ?? 'Conversation')),
      ),
      body: Column(
        children: [
          Expanded(
            child: thread.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not open this conversation.\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary)),
                ),
              ),
              data: (state) {
                if (state.messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say something.',
                        style: TextStyle(color: AppColors.textSecondary)),
                  );
                }

                _scrollDown();

                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  itemCount: state.messages.length,
                  itemBuilder: (_, i) {
                    final m = state.messages[i];
                    return _Bubble(
                      message: m,
                      receipt: m.mine ? state.marks.forMessage(m.ts) : null,
                      showReadWord: m.id == state.lastMineId,
                    );
                  },
                );
              },
            ),
          ),
          _composer(thread.valueOrNull?.sending ?? false),
        ],
      ),
    );
  }

  Widget _composer(bool sending) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_recording)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.fiber_manual_record, size: 12, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text('Recording  ${_seconds}s',
                        style: const TextStyle(
                            color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 12)),
                    const Spacer(),
                    TextButton(
                      onPressed: () => _stopRecording(send: false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => _stopRecording(),
                      child: const Text('Send'),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Attach a photo, video or file',
                  icon: const Icon(Icons.attach_file_rounded, color: AppColors.textMuted),
                  onPressed: sending || _recording ? null : _attach,
                ),
                IconButton(
                  tooltip: 'Voice note',
                  icon: Icon(Icons.mic_rounded,
                      color: _recording ? AppColors.error : AppColors.textMuted),
                  onPressed: sending
                      ? null
                      : (_recording ? () => _stopRecording() : _startRecording),
                ),
                Expanded(
                  child: TextField(
                    controller: _draft,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Write a message...',
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                IconButton(
                  icon: sending
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_rounded, color: AppColors.primary),
                  onPressed: sending ? null : _sendText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One message.
class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final Receipt? receipt;
  final bool showReadWord;

  const _Bubble({required this.message, this.receipt, this.showReadWord = false});

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          // Your own bubble is tinted, not solid: a grey tick and a blue tick
          // cannot be told apart on a strong colour, and telling them apart is
          // the whole point of a receipt.
          color: mine ? const Color(0xFFDBEAFE) : AppColors.cardBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!mine && message.sender != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(message.sender!,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark)),
              ),

            if (message.hasAttachment) _Attachment(message: message),

            if ((message.body ?? '').isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: message.hasAttachment ? 6 : 0),
                child: Text(message.body!,
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
              ),

            const SizedBox(height: 3),

            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(message.at,
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                if (receipt != null) ...[
                  const SizedBox(width: 4),
                  Icon(
                    receipt == Receipt.sent ? Icons.check_rounded : Icons.done_all_rounded,
                    size: 14,
                    color: receipt == Receipt.read ? AppColors.primary : AppColors.textMuted,
                  ),
                  if (showReadWord && receipt == Receipt.read) ...[
                    const SizedBox(width: 3),
                    const Text('Read',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ],
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A picture is shown, a recording is played, anything else is opened with
/// whatever the phone uses for it.
class _Attachment extends StatelessWidget {
  final ChatMessage message;

  const _Attachment({required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.isAudio) return _VoiceNote(message: message);

    if (message.isImage) {
      return FutureBuilder<Map<String, String>>(
        future: chatAuthHeaders(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const SizedBox(
                height: 140, child: Center(child: CircularProgressIndicator()));
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: message.url!,
              httpHeaders: snap.data,
              fit: BoxFit.cover,
              placeholder: (_, _) => const SizedBox(
                  height: 140, child: Center(child: CircularProgressIndicator())),
              errorWidget: (_, _, _) =>
                  const _FileRow(icon: Icons.broken_image_rounded, label: 'Image unavailable'),
            ),
          );
        },
      );
    }

    return InkWell(
      onTap: () => openChatAttachment(context, message),
      child: _FileRow(
        icon: message.isVideo ? Icons.play_circle_fill_rounded : Icons.insert_drive_file_rounded,
        label: message.fileName ?? (message.isVideo ? 'Video' : 'File'),
        detail: message.fileSize,
      ),
    );
  }
}

class _FileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;

  const _FileRow({required this.icon, required this.label, this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              if (detail != null)
                Text(detail!,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Plays a voice note inline.
///
/// The file sits behind the same membership check as the thread, so it cannot
/// be streamed from the URL by a player that carries no token: it is fetched
/// once with the token and played from disk.
class _VoiceNote extends StatefulWidget {
  final ChatMessage message;

  const _VoiceNote({required this.message});

  @override
  State<_VoiceNote> createState() => _VoiceNoteState();
}

class _VoiceNoteState extends State<_VoiceNote> {
  final _player = AudioPlayer();
  bool _busy = false;
  bool _playing = false;
  String? _localPath;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _playing = s == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }

    if (_localPath != null) {
      await _player.play(DeviceFileSource(_localPath!));
      return;
    }

    setState(() => _busy = true);

    try {
      _localPath = await downloadChatAttachment(widget.message);
      await _player.play(DeviceFileSource(_localPath!));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not play that recording.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: _busy ? null : _toggle,
          icon: _busy
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(_playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                  color: AppColors.primary, size: 30),
        ),
        const Icon(Icons.graphic_eq_rounded, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          widget.message.durationLabel.isEmpty ? 'Voice note' : widget.message.durationLabel,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

/// Fetch an attachment to a file the phone can open, carrying the token.
Future<String> downloadChatAttachment(ChatMessage message) async {
  final dir = await getTemporaryDirectory();
  final name = message.fileName?.replaceAll(RegExp(r'[^\w\.\-]'), '_') ?? 'attachment';
  final path = '${dir.path}${Platform.pathSeparator}chat-${message.id}-$name';

  final file = File(path);
  if (file.existsSync() && await file.length() > 0) return path;

  await ApiService.dio.download(
    message.url!,
    path,
    options: Options(headers: await chatAuthHeaders()),
  );

  return path;
}

/// Open a video or document with whatever the phone uses for it.
Future<void> openChatAttachment(BuildContext context, ChatMessage message) async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    final path = await downloadChatAttachment(message);
    final result = await OpenFilex.open(path);

    if (result.type != ResultType.done) {
      messenger.showSnackBar(
        SnackBar(content: Text('Nothing on this device opens that file.')),
      );
    }
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Could not download that attachment.')),
    );
  }
}
