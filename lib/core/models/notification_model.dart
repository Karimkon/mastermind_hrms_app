class NotificationModel {
  final String id;
  final String type;

  /// Which menu item this notice belongs to ('pips', 'payslips', 'leave'…).
  /// Null for kinds that have no item of their own, such as chat.
  final String? area;

  final String title;
  final String body;
  final String? actionUrl;
  final Map<String, dynamic> data;
  final String? readAt;
  final String createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    this.area,
    required this.title,
    required this.body,
    this.actionUrl,
    required this.data,
    this.readAt,
    required this.createdAt,
  });

  bool get read => readAt != null;

  String get message => body;

  String get timeAgo {
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  /// Last resort when the server sent no title: 'payroll_processed' reads
  /// better as 'Payroll processed' than as nothing at all.
  static String _prettify(String type) {
    if (type.isEmpty) return 'Notification';
    final words = type.split(RegExp(r'[_\\\\]')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return 'Notification';
    final first = words.first;
    return ([first[0].toUpperCase() + first.substring(1)] + words.skip(1).toList()).join(' ');
  }

  /// `title` and `body` are columns on the server's notifications table, not
  /// keys inside `data`. This used to read them from `data` only, so every
  /// notice showed a prettified type string and an empty message. The `data`
  /// fallbacks stay for any notice written the older way.
  factory NotificationModel.fromJson(Map<String, dynamic> j) {
    final data = Map<String, dynamic>.from(j['data'] ?? const {});
    final type = (j['type'] ?? '').toString();

    return NotificationModel(
      id: j['id'].toString(),
      type: type,
      area: j['area'] as String?,
      title: (j['title'] as String?)?.trim().isNotEmpty == true
          ? j['title'] as String
          : (data['title'] as String? ?? _prettify(type)),
      body: (j['body'] as String?) ?? (data['message'] as String? ?? data['body'] as String? ?? ''),
      actionUrl: j['action_url'] as String? ?? data['url'] as String?,
      data: data,
      readAt: j['read_at'] as String?,
      createdAt: j['created_at'] as String? ?? '',
    );
  }
}
