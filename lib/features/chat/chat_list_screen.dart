import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_colors.dart';
import '../../core/models/chat_model.dart';
import '../../core/providers/chat_provider.dart';

/// The threads you are in, most recent first.
class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chats = ref.watch(chatListProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(chatListProvider.notifier).refresh(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _pickContact(context, ref),
        child: const Icon(Icons.edit_rounded, color: Colors.white),
      ),
      body: chats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Message(
          icon: Icons.cloud_off_rounded,
          title: 'Could not load your messages',
          detail: '$e',
          onRetry: () => ref.read(chatListProvider.notifier).refresh(),
        ),
        data: (data) {
          if (data.conversations.isEmpty) {
            return const _Message(
              icon: Icons.forum_outlined,
              title: 'No conversations yet',
              detail: 'Tap the pencil to write to somebody.',
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(chatListProvider.notifier).refresh(),
            child: ListView.separated(
              itemCount: data.conversations.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (_, i) => _ConversationTile(c: data.conversations[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickContact(BuildContext context, WidgetRef ref) async {
    final userId = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ContactPicker(),
    );

    if (userId == null || !context.mounted) return;

    final id = await openDirectThread(userId);

    if (id == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open that conversation.')),
        );
      }
      return;
    }

    if (context.mounted) {
      ref.read(chatListProvider.notifier).refresh();
      context.push('/chat/$id');
    }
  }
}

class _ConversationTile extends StatelessWidget {
  final ChatConversation c;

  const _ConversationTile({required this.c});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () => context.push('/chat/${c.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Avatar(url: c.avatar, name: c.title, group: c.isGroup),
      title: Text(
        c.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: c.unread > 0 ? FontWeight.w700 : FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: Text(
        c.preview ?? (c.isGroup ? '${c.members} members' : 'No messages yet'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(c.whenLabel,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          if (c.unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                c.unread > 99 ? '99+' : '${c.unread}',
                style: const TextStyle(
                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            )
          else
            const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String name;
  final bool group;

  const _Avatar({this.url, required this.name, this.group = false});

  @override
  Widget build(BuildContext context) {
    if (group) {
      return const CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primaryLight,
        child: Icon(Icons.groups_rounded, color: Colors.white),
      );
    }

    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();

    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundColor: AppColors.primaryDark,
        child: Text(initials,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      );
    }

    // The avatar is a public URL, unlike a chat attachment, so it needs no token.
    return CircleAvatar(
      radius: 22,
      backgroundColor: AppColors.primaryDark,
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => Text(initials,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

/// Search the staff list and pick somebody to write to.
class _ContactPicker extends ConsumerStatefulWidget {
  const _ContactPicker();

  @override
  ConsumerState<_ContactPicker> createState() => _ContactPickerState();
}

class _ContactPickerState extends ConsumerState<_ContactPicker> {
  final _search = TextEditingController();
  String _term = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(chatContactsProvider(_term));

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.inputBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (v) => setState(() => _term = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search staff by name or email',
                  prefixIcon: const Icon(Icons.search_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            Expanded(
              child: contacts.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Could not load staff.\n$e',
                    textAlign: TextAlign.center)),
                data: (list) => list.isEmpty
                    ? const Center(child: Text('Nobody matches that.'))
                    : ListView.builder(
                        controller: controller,
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final u = list[i];
                          return ListTile(
                            leading: _Avatar(
                                url: u['avatar'] as String?,
                                name: u['name'] as String? ?? '?'),
                            title: Text(u['name'] as String? ?? ''),
                            subtitle: Text(u['email'] as String? ?? '',
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () =>
                                Navigator.pop(context, (u['id'] as num).toInt()),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? detail;
  final VoidCallback? onRetry;

  const _Message({required this.icon, required this.title, this.detail, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(detail!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          ],
        ),
      ),
    );
  }
}
