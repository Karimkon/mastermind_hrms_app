/// Staff messaging: the same threads the web panel shows.
library;

/// How far a message of your own has got.
enum Receipt { sent, delivered, read }

/// How far everybody else in a thread has got.
///
/// Two moments in time rather than a flag per message: the server sends these
/// with every poll, so ticks already on screen can move without the messages
/// under them being fetched again.
class ChatMarks {
  final int? delivered;
  final int? read;

  const ChatMarks({this.delivered, this.read});

  const ChatMarks.none() : delivered = null, read = null;

  factory ChatMarks.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const ChatMarks.none();
    return ChatMarks(
      delivered: (j['delivered'] as num?)?.toInt(),
      read: (j['read'] as num?)?.toInt(),
    );
  }

  Receipt forMessage(int? ts) {
    if (ts == null) return Receipt.sent;
    if (read != null && read! >= ts) return Receipt.read;
    if (delivered != null && delivered! >= ts) return Receipt.delivered;
    return Receipt.sent;
  }
}

class ChatConversation {
  final int id;
  final String type;
  final String title;
  final String? avatar;
  final String? preview;
  final String? at;
  final int unread;
  final int members;

  const ChatConversation({
    required this.id,
    required this.type,
    required this.title,
    this.avatar,
    this.preview,
    this.at,
    this.unread = 0,
    this.members = 0,
  });

  bool get isGroup => type == 'group';

  /// A short, human "when", from the ISO timestamp the API sends.
  String get whenLabel {
    if (at == null) return '';
    final dt = DateTime.tryParse(at!);
    if (dt == null) return '';

    final now = DateTime.now();
    final local = dt.toLocal();
    final sameDay = local.year == now.year && local.month == now.month && local.day == now.day;

    if (sameDay) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }

    final diff = now.difference(local);
    if (diff.inDays < 7) return '${diff.inDays}d';

    return '${local.day}/${local.month}';
  }

  factory ChatConversation.fromJson(Map<String, dynamic> j) => ChatConversation(
        id: (j['id'] as num).toInt(),
        type: j['type'] as String? ?? 'direct',
        title: j['title'] as String? ?? 'Conversation',
        avatar: j['avatar'] as String?,
        preview: j['preview'] as String?,
        at: j['at'] as String?,
        unread: (j['unread'] as num?)?.toInt() ?? 0,
        members: (j['members'] as num?)?.toInt() ?? 0,
      );
}

class ChatMessage {
  final int id;
  final bool mine;
  final int? ts;
  final String? sender;
  final String? avatar;

  /// text | image | audio | video | file
  final String type;
  final String? body;

  final String? url;
  final String? fileName;
  final String? fileSize;
  final String? mime;

  /// Seconds, for a voice note.
  final int? duration;

  final String at;
  final String on;

  const ChatMessage({
    required this.id,
    required this.mine,
    this.ts,
    this.sender,
    this.avatar,
    required this.type,
    this.body,
    this.url,
    this.fileName,
    this.fileSize,
    this.mime,
    this.duration,
    this.at = '',
    this.on = '',
  });

  bool get hasAttachment => url != null;
  bool get isImage => type == 'image';
  bool get isAudio => type == 'audio';
  bool get isVideo => type == 'video';
  bool get isFile => type == 'file';

  /// mm:ss, for a voice note's length.
  String get durationLabel {
    final d = duration;
    if (d == null || d <= 0) return '';
    final m = (d ~/ 60).toString();
    final s = (d % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: (j['id'] as num).toInt(),
        mine: j['mine'] == true,
        ts: (j['ts'] as num?)?.toInt(),
        sender: j['sender'] as String?,
        avatar: j['avatar'] as String?,
        type: j['type'] as String? ?? 'text',
        body: j['body'] as String?,
        url: j['url'] as String?,
        fileName: j['file_name'] as String?,
        fileSize: j['file_size'] as String?,
        mime: j['mime'] as String?,
        duration: (j['duration'] as num?)?.toInt(),
        at: j['at'] as String? ?? '',
        on: j['on'] as String? ?? '',
      );
}
