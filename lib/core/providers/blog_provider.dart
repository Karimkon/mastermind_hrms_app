import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/api_constants.dart';
import '../models/blog_model.dart';
import '../services/api_service.dart';

/// Filters applied on the insights list screen.
@immutable
class BlogFilter {
  final String? categorySlug;
  final String? query;

  const BlogFilter({this.categorySlug, this.query});

  BlogFilter copyWith({
    String? categorySlug,
    String? query,
    bool clearCategory = false,
    bool clearQuery = false,
  }) {
    return BlogFilter(
      categorySlug: clearCategory ? null : (categorySlug ?? this.categorySlug),
      query: clearQuery ? null : (query ?? this.query),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BlogFilter && other.categorySlug == categorySlug && other.query == query;

  @override
  int get hashCode => Object.hash(categorySlug, query);
}

final blogFilterProvider = StateProvider<BlogFilter>((ref) => const BlogFilter());

/// One page of articles for the active filter.
final blogArticlesProvider =
    FutureProvider.family<BlogPage, BlogFilter>((ref, filter) async {
  final params = <String, dynamic>{'per_page': 12};
  if (filter.categorySlug != null) params['category'] = filter.categorySlug;
  if ((filter.query ?? '').trim().isNotEmpty) params['q'] = filter.query!.trim();

  final res = await ApiService.get(ApiConstants.blogArticles, params: params);

  if (res.data is Map) {
    return BlogPage.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  return BlogPage(articles: const []);
});

/// A single article, body already parsed into render blocks by the server.
final blogArticleProvider =
    FutureProvider.family<BlogArticleModel?, String>((ref, slug) async {
  final res = await ApiService.get(ApiConstants.blogArticle(slug));

  if (res.data is Map) {
    final map = Map<String, dynamic>.from(res.data as Map);
    if (map['data'] is Map) {
      return BlogArticleModel.fromJson(Map<String, dynamic>.from(map['data'] as Map));
    }
  }

  return null;
});

/// Topics shown as filter chips.
final blogCategoriesProvider = FutureProvider<List<BlogCategoryModel>>((ref) async {
  final res = await ApiService.get(ApiConstants.blogTopics);

  if (res.data is Map) {
    final data = Map<String, dynamic>.from(res.data as Map)['data'];
    if (data is Map && data['categories'] is List) {
      return (data['categories'] as List)
          .whereType<Map<String, dynamic>>()
          .map(BlogCategoryModel.fromJson)
          .where((c) => c.postsCount > 0)
          .toList();
    }
  }

  return const [];
});

/// The newest few articles, for the card on the dashboard.
final latestBlogArticlesProvider = FutureProvider<List<BlogArticleModel>>((ref) async {
  try {
    final res = await ApiService.get(ApiConstants.blogArticles, params: {'per_page': 4});

    if (res.data is Map) {
      return BlogPage.fromJson(Map<String, dynamic>.from(res.data as Map)).articles;
    }
  } catch (e) {
    if (kDebugMode) debugPrint('latestBlogArticlesProvider failed: $e');
  }

  return const [];
});
