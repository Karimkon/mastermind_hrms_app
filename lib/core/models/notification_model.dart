class NotificationModel {
  final String id;
  final String type;
  final Map<String, dynamic> data;
  final String? readAt;
  final String createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.data,
    this.readAt,
    required this.createdAt,
  });

  bool get read => readAt != null;

  String get title => data['title'] as String? ?? _typeToTitle(type);
  String get message => data['message'] as String? ?? data['body'] as String? ?? '';

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

  String _typeToTitle(String type) {
    return type.split('\\').last.replaceAll('Notification', '').replaceAllMapped(
      RegExp(r'([A-Z])'),
      (m) => ' ${m.group(1)}',
    ).trim();
  }

  factory NotificationModel.fromJson(Map<String, dynamic> j) => NotificationModel(
        id: j['id'].toString(),
        type: j['type'] ?? '',
        data: Map<String, dynamic>.from(j['data'] ?? {}),
        readAt: j['read_at'],
        createdAt: j['created_at'] ?? '',
      );
}
