import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../models/chat_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

/// The list of threads, and the unread badge.
class ChatListState {
  final List<ChatConversation> conversations;
  final int unread;

  const ChatListState({this.conversations = const [], this.unread = 0});
}

class ChatListNotifier extends AsyncNotifier<ChatListState> {
  @override
  Future<ChatListState> build() => _fetch();

  Future<ChatListState> _fetch() async {
    final res = await ApiService.get(ApiConstants.chat);
    final body = res.data as Map<String, dynamic>;

    return ChatListState(
      conversations: ((body['conversations'] as List?) ?? const [])
          .map((j) => ChatConversation.fromJson(Map<String, dynamic>.from(j)))
          .toList(),
      unread: (body['unread'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }
}

final chatListProvider =
    AsyncNotifierProvider<ChatListNotifier, ChatListState>(ChatListNotifier.new);

/// Just the badge, for the shell. Cheap enough to poll on its own.
final chatUnreadProvider = FutureProvider.autoDispose<int>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.chatUnread);
    return ((res.data as Map)['unread'] as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});

/// One open thread.
class ThreadState {
  final List<ChatMessage> messages;
  final ChatMarks marks;
  final String title;
  final bool sending;
  final String? error;

  const ThreadState({
    this.messages = const [],
    this.marks = const ChatMarks.none(),
    this.title = '',
    this.sending = false,
    this.error,
  });

  ThreadState copyWith({
    List<ChatMessage>? messages,
    ChatMarks? marks,
    String? title,
    bool? sending,
    String? error,
    bool clearError = false,
  }) =>
      ThreadState(
        messages: messages ?? this.messages,
        marks: marks ?? this.marks,
        title: title ?? this.title,
        sending: sending ?? this.sending,
        error: clearError ? null : (error ?? this.error),
      );

  /// The newest message of your own: the one that carries the word "Read"
  /// rather than only the ticks.
  int? get lastMineId {
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].mine) return messages[i].id;
    }
    return null;
  }
}

/// Polls while a thread is on screen. There is no websocket on this host, so
/// new lines arrive by asking.
class ThreadNotifier extends AutoDisposeFamilyAsyncNotifier<ThreadState, int> {
  Timer? _poll;
  int _lastId = 0;

  @override
  Future<ThreadState> build(int conversationId) async {
    ref.onDispose(() => _poll?.cancel());

    final loaded = await _load(conversationId);

    _poll = Timer.periodic(const Duration(seconds: 5), (_) => _fetchNew(conversationId));

    return loaded;
  }

  Future<ThreadState> _load(int id) async {
    final res = await ApiService.get('${ApiConstants.chat}/$id/messages');
    final body = res.data as Map<String, dynamic>;

    final messages = ((body['messages'] as List?) ?? const [])
        .map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j)))
        .toList();

    _lastId = messages.isEmpty ? 0 : messages.last.id;

    return ThreadState(
      messages: messages,
      marks: ChatMarks.fromJson(body['marks'] as Map<String, dynamic>?),
      title: body['title'] as String? ?? '',
    );
  }

  Future<void> _fetchNew(int id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    try {
      final res = await ApiService.get('${ApiConstants.chat}/$id/messages',
          params: {'after': _lastId});
      final body = res.data as Map<String, dynamic>;

      final fresh = ((body['messages'] as List?) ?? const [])
          .map((j) => ChatMessage.fromJson(Map<String, dynamic>.from(j)))
          .toList();

      // Always, even when nothing new arrived: a poll that returns no messages
      // is exactly when the other person has been reading the ones on screen.
      final marks = ChatMarks.fromJson(body['marks'] as Map<String, dynamic>?);

      if (fresh.isEmpty) {
        state = AsyncData(current.copyWith(marks: marks));
        return;
      }

      _lastId = fresh.last.id;
      state = AsyncData(current.copyWith(
        messages: [...current.messages, ...fresh],
        marks: marks,
      ));
    } catch (_) {
      // A failed poll is not worth interrupting anybody for.
    }
  }

  /// Send words, a file, or both.
  Future<bool> send(int id, {String? body, File? file, String? kind, int? duration}) async {
    final current = state.valueOrNull;
    if (current == null || current.sending) return false;

    final text = (body ?? '').trim();
    if (text.isEmpty && file == null) return false;

    state = AsyncData(current.copyWith(sending: true, clearError: true));

    try {
      final form = FormData.fromMap({
        if (text.isNotEmpty) 'body': text,
        'kind': ?kind,
        if (duration != null && duration > 0) 'duration': duration,
        if (file != null)
          'attachment': await MultipartFile.fromFile(file.path,
              filename: file.path.split(Platform.pathSeparator).last),
      });

      final res = await ApiService.postForm('${ApiConstants.chat}/$id/send', form);
      final data = res.data as Map<String, dynamic>;

      final sent = ChatMessage.fromJson(Map<String, dynamic>.from(data['message']));
      _lastId = sent.id;

      final now = state.valueOrNull ?? current;
      state = AsyncData(now.copyWith(
        messages: [...now.messages, sent],
        marks: ChatMarks.fromJson(data['marks'] as Map<String, dynamic>?),
        sending: false,
        clearError: true,
      ));

      ref.read(chatListProvider.notifier).refresh();
      return true;
    } on DioException catch (e) {
      // A refusal is the sender's business: a file too large, or a type the
      // server will not take. Laravel puts the detail in errors, not message.
      final data = e.response?.data;
      String? detail;

      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          detail = first is List && first.isNotEmpty ? first.first.toString() : null;
        }
        detail ??= data['message'] as String?;
      }

      final now = state.valueOrNull ?? current;
      state = AsyncData(now.copyWith(
        sending: false,
        error: detail ?? 'That did not send. Check your connection.',
      ));
      return false;
    } catch (_) {
      final now = state.valueOrNull ?? current;
      state = AsyncData(now.copyWith(
        sending: false,
        error: 'That did not send. Check your connection.',
      ));
      return false;
    }
  }

  void clearError() {
    final current = state.valueOrNull;
    if (current != null) state = AsyncData(current.copyWith(clearError: true));
  }
}

final threadProvider =
    AsyncNotifierProvider.autoDispose.family<ThreadNotifier, ThreadState, int>(
  ThreadNotifier.new,
);

/// Who can be written to.
final chatContactsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, term) async {
  final res = await ApiService.get(ApiConstants.chatContacts,
      params: term.isEmpty ? null : {'q': term});

  return ((res.data as Map)['contacts'] as List? ?? const [])
      .map((j) => Map<String, dynamic>.from(j))
      .toList();
});

/// Start, or reopen, a one-to-one thread.
Future<int?> openDirectThread(int userId) async {
  try {
    final res = await ApiService.post('${ApiConstants.chat}/with/$userId');
    return ((res.data as Map)['conversation_id'] as num?)?.toInt();
  } catch (_) {
    return null;
  }
}

/// Attachments are behind the same membership check as the thread, so every
/// fetch has to carry the token. Images and video players take headers; a
/// download needs them set by hand.
Future<Map<String, String>> chatAuthHeaders() async {
  final token = await StorageService.getToken();
  return token == null ? {} : {'Authorization': 'Bearer $token'};
}
