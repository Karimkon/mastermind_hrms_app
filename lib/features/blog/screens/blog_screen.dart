import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/models/blog_model.dart';
import '../../../core/providers/blog_provider.dart';

class BlogScreen extends ConsumerStatefulWidget {
  const BlogScreen({super.key});

  @override
  ConsumerState<BlogScreen> createState() => _BlogScreenState();
}

class _BlogScreenState extends ConsumerState<BlogScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _categoryColor(String? hex) {
    if (hex == null || hex.isEmpty) return AppColors.primary;
    final value = int.tryParse('FF${hex.replaceAll('#', '')}', radix: 16);
    return value == null ? AppColors.primary : Color(value);
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(blogFilterProvider);
    final articles = ref.watch(blogArticlesProvider(filter));
    final categories = ref.watch(blogCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Company Insights'),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(blogArticlesProvider);
          ref.invalidate(blogCategoriesProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.primaryDark,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (value) {
                    ref.read(blogFilterProvider.notifier).state = value.trim().isEmpty
                        ? filter.copyWith(clearQuery: true)
                        : filter.copyWith(query: value.trim());
                  },
                  decoration: InputDecoration(
                    hintText: 'Search articles',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: (filter.query ?? '').isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(blogFilterProvider.notifier).state =
                                  filter.copyWith(clearQuery: true);
                            },
                          ),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: categories.when(
                data: (list) {
                  if (list.isEmpty) return const SizedBox(height: 8);

                  return SizedBox(
                    height: 56,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      children: [
                        _TopicChip(
                          label: 'All',
                          selected: filter.categorySlug == null,
                          color: AppColors.primary,
                          onTap: () => ref.read(blogFilterProvider.notifier).state =
                              filter.copyWith(clearCategory: true),
                        ),
                        ...list.map(
                          (category) => _TopicChip(
                            label: category.name,
                            selected: filter.categorySlug == category.slug,
                            color: _categoryColor(category.color),
                            onTap: () => ref.read(blogFilterProvider.notifier).state =
                                filter.copyWith(categorySlug: category.slug),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const SizedBox(height: 56),
                error: (_, _) => const SizedBox(height: 8),
              ),
            ),

            articles.when(
              data: (page) {
                if (page.articles.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _Empty(hasQuery: (filter.query ?? '').isNotEmpty),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ArticleCard(
                        article: page.articles[index],
                        accent: _categoryColor(page.articles[index].categoryColor),
                        lead: index == 0,
                      ),
                      childCount: page.articles.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      const Text("We couldn't load the insights",
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                      const SizedBox(height: 6),
                      const Text('Check your connection and try again.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => ref.invalidate(blogArticlesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopicChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _TopicChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? color : AppColors.inputBorder),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  final BlogArticleModel article;
  final Color accent;
  final bool lead;

  const _ArticleCard({required this.article, required this.accent, this.lead = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/blog/${article.slug}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: lead
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _Cover(url: article.image, accent: accent),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _Text(article: article, accent: accent, big: true),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 104,
                        height: 92,
                        child: _Cover(url: article.image, accent: accent),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: _Text(article: article, accent: accent)),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Text extends StatelessWidget {
  final BlogArticleModel article;
  final Color accent;
  final bool big;

  const _Text({required this.article, required this.accent, this.big = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (article.categoryName != null)
          Text(
            article.categoryName!.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.5,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          article.title,
          maxLines: big ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: big ? 17 : 14.5,
            height: 1.3,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (big) ...[
          const SizedBox(height: 6),
          Text(
            article.excerpt,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text('${article.readingTime} min read',
                style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            if (article.publishedLabel.isNotEmpty) ...[
              const Text('  ·  ', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Flexible(
                child: Text(
                  article.publishedLabel,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  final String? url;
  final Color accent;

  const _Cover({required this.url, required this.accent});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        color: accent.withValues(alpha: 0.10),
        child: Icon(Icons.lightbulb_outline, color: accent.withValues(alpha: 0.6), size: 28),
      );
    }

    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (context, _) => Container(color: AppColors.divider),
      errorWidget: (context, _, _) => Container(
        color: accent.withValues(alpha: 0.10),
        child: Icon(Icons.image_not_supported_outlined, color: accent.withValues(alpha: 0.6)),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final bool hasQuery;

  const _Empty({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.article_outlined, size: 52, color: AppColors.textMuted),
          const SizedBox(height: 14),
          Text(
            hasQuery ? 'No articles match that search' : 'No articles yet',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            hasQuery
                ? 'Try a different word, or clear the search.'
                : 'Company news and HR guidance will appear here.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
