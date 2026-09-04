import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/blog_model.dart';
import '../../../core/providers/blog_provider.dart';

class BlogDetailScreen extends ConsumerWidget {
  final String slug;

  const BlogDetailScreen({super.key, required this.slug});

  Color _accent(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    final value = int.tryParse('FF${hex.replaceAll('#', '')}', radix: 16);
    return value == null ? AppColors.primary : Color(value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final article = ref.watch(blogArticleProvider(slug));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: article.when(
        data: (post) {
          if (post == null) {
            return _Message(
              icon: Icons.search_off,
              title: 'Article not found',
              body: 'It may have been unpublished. Browse the insights for the latest articles.',
              actionLabel: 'Back to insights',
              onAction: () => context.pop(),
            );
          }

          return _Body(post: post, accent: _accent(post.categoryColor));
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _Message(
          icon: Icons.wifi_off,
          title: "We couldn't load this article",
          body: 'Check your connection and try again.',
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(blogArticleProvider(slug)),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final BlogArticleModel post;
  final Color accent;

  const _Body({required this.post, required this.accent});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: post.image != null ? 220 : 0,
          pinned: true,
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: 'Copy link',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: post.url));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Link copied')),
                  );
                }
              },
            ),
          ],
          flexibleSpace: post.image == null
              ? null
              : FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: post.image!,
                        fit: BoxFit.cover,
                        placeholder: (context, _) => Container(color: AppColors.divider),
                        errorWidget: (context, _, _) => Container(color: AppColors.divider),
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.black54, Colors.transparent, Colors.black26],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),

        SliverToBoxAdapter(
          child: Container(
            color: AppColors.cardBg,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (post.categoryName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      post.categoryName!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  post.title,
                  style: const TextStyle(
                    fontSize: 24,
                    height: 1.25,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if ((post.subtitle ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    post.subtitle!,
                    style: const TextStyle(
                        fontSize: 15, height: 1.5, color: AppColors.textSecondary),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: accent.withValues(alpha: 0.15),
                      child: Text(
                        post.author.isNotEmpty ? post.author[0].toUpperCase() : 'M',
                        style: TextStyle(
                            color: accent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post.author,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          Text(
                            [post.publishedLabel, '${post.readingTime} min read']
                                .where((s) => s.isNotEmpty)
                                .join('  ·  '),
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _Block(block: post.blocks[index], accent: accent),
              childCount: post.blocks.length,
            ),
          ),
        ),

        if (post.tags.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: post.tags
                    .map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: AppColors.inputBorder),
                          ),
                          child: Text('#$tag',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary)),
                        ))
                    .toList(),
              ),
            ),
          ),

        if (post.faqs.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Text('Frequently asked questions',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold)),
                  ),
                  ...post.faqs.map(
                    (faq) => ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(faq.question,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(faq.answer,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    height: 1.55,
                                    color: AppColors.textSecondary)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (post.related.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Keep reading',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...post.related.map(
                    (item) => GestureDetector(
                      onTap: () => context.push('/blog/${item.slug}'),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.cardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 64,
                                height: 60,
                                child: (item.image ?? '').isEmpty
                                    ? Container(color: AppColors.divider)
                                    : CachedNetworkImage(
                                        imageUrl: item.image!,
                                        fit: BoxFit.cover,
                                        errorWidget: (c, _, _) =>
                                            Container(color: AppColors.divider),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13.5,
                                      height: 1.3,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }
}

class _Block extends StatelessWidget {
  final BlogBlock block;
  final Color accent;

  const _Block({required this.block, required this.accent});

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case 'heading':
        return Padding(
          padding: EdgeInsets.only(top: block.level == 2 ? 24 : 18, bottom: 8),
          child: Text(
            block.text,
            style: TextStyle(
              fontSize: block.level == 2 ? 18.5 : 16,
              height: 1.3,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        );

      case 'image':
        if (block.url.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: CachedNetworkImage(
                  imageUrl: block.url,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (c, _) => Container(height: 180, color: AppColors.divider),
                  errorWidget: (c, _, _) => Container(height: 120, color: AppColors.divider),
                ),
              ),
              if (block.caption.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(block.caption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ],
          ),
        );

      case 'list':
        return Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(block.items.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        block.ordered ? '${i + 1}.' : '•',
                        style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            fontWeight: FontWeight.bold,
                            color: accent),
                      ),
                    ),
                    Expanded(
                      child: Text(block.items[i],
                          style: const TextStyle(
                              fontSize: 15, height: 1.6, color: AppColors.textSecondary)),
                    ),
                  ],
                ),
              );
            }),
          ),
        );

      case 'quote':
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 14),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.07),
            border: Border(left: BorderSide(color: accent, width: 4)),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Text(
            block.text,
            style: const TextStyle(
                fontSize: 15,
                height: 1.6,
                fontStyle: FontStyle.italic,
                color: AppColors.textPrimary),
          ),
        );

      case 'code':
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.sidebarBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              block.text,
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  height: 1.5,
                  color: Color(0xFFE2E8F0)),
            ),
          ),
        );

      case 'divider':
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Divider(color: AppColors.divider),
        );

      case 'html':
        return const SizedBox.shrink();

      default:
        if (block.text.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            block.text,
            style: const TextStyle(
                fontSize: 15.5, height: 1.7, color: AppColors.textSecondary),
          ),
        );
    }
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 52, color: AppColors.textMuted),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
