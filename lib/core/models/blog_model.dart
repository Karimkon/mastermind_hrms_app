// lib/core/models/blog_model.dart
// Blog models mapped to the /api/blog/* feed served by the Laravel backend.

class BlogCategoryModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? color;
  final String? image;
  final int postsCount;

  BlogCategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.color,
    this.image,
    this.postsCount = 0,
  });

  factory BlogCategoryModel.fromJson(Map<String, dynamic> json) {
    return BlogCategoryModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      description: json['description']?.toString(),
      color: json['color']?.toString(),
      image: json['image']?.toString(),
      postsCount: json['posts_count'] is int
          ? json['posts_count']
          : int.tryParse('${json['posts_count']}') ?? 0,
    );
  }
}

/// One piece of an article body, already parsed server-side so the app can
/// render it with native widgets instead of a web view.
class BlogBlock {
  final String type; // heading | paragraph | image | list | quote | code | divider | html
  final String text;
  final String html;
  final int level;
  final String url;
  final String alt;
  final String caption;
  final bool ordered;
  final List<String> items;

  BlogBlock({
    required this.type,
    this.text = '',
    this.html = '',
    this.level = 2,
    this.url = '',
    this.alt = '',
    this.caption = '',
    this.ordered = false,
    this.items = const [],
  });

  factory BlogBlock.fromJson(Map<String, dynamic> json) {
    return BlogBlock(
      type: json['type']?.toString() ?? 'paragraph',
      text: json['text']?.toString() ?? '',
      html: json['html']?.toString() ?? '',
      level: json['level'] is int ? json['level'] : int.tryParse('${json['level']}') ?? 2,
      url: json['url']?.toString() ?? '',
      alt: json['alt']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      ordered: json['ordered'] == true,
      items: (json['items'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    );
  }
}

class BlogFaq {
  final String question;
  final String answer;

  BlogFaq({required this.question, required this.answer});

  factory BlogFaq.fromJson(Map<String, dynamic> json) => BlogFaq(
        question: json['question']?.toString() ?? '',
        answer: json['answer']?.toString() ?? '',
      );
}

class BlogArticleModel {
  final int id;
  final String title;
  final String slug;
  final String? subtitle;
  final String excerpt;
  final String? image;
  final String? imageAlt;
  final String? categoryName;
  final String? categorySlug;
  final String? categoryColor;
  final List<String> tags;
  final String author;
  final String? authorTitle;
  final String? authorAvatar;
  final int readingTime;
  final int views;
  final bool isFeatured;
  final DateTime? publishedAt;
  final String url;

  // Only present on the detail response
  final List<BlogBlock> blocks;
  final List<BlogFaq> faqs;
  final List<BlogArticleModel> related;

  BlogArticleModel({
    required this.id,
    required this.title,
    required this.slug,
    this.subtitle,
    this.excerpt = '',
    this.image,
    this.imageAlt,
    this.categoryName,
    this.categorySlug,
    this.categoryColor,
    this.tags = const [],
    this.author = '',
    this.authorTitle,
    this.authorAvatar,
    this.readingTime = 1,
    this.views = 0,
    this.isFeatured = false,
    this.publishedAt,
    this.url = '',
    this.blocks = const [],
    this.faqs = const [],
    this.related = const [],
  });

  factory BlogArticleModel.fromJson(Map<String, dynamic> json) {
    final category = json['category'];

    return BlogArticleModel(
      id: json['id'] is int ? json['id'] : int.tryParse('${json['id']}') ?? 0,
      title: json['title']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      excerpt: json['excerpt']?.toString() ?? '',
      image: json['image']?.toString(),
      imageAlt: json['image_alt']?.toString(),
      categoryName: category is Map ? category['name']?.toString() : null,
      categorySlug: category is Map ? category['slug']?.toString() : null,
      categoryColor: category is Map ? category['color']?.toString() : null,
      tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      author: json['author']?.toString() ?? 'Mastermind',
      authorTitle: json['author_title']?.toString(),
      authorAvatar: json['author_avatar']?.toString(),
      readingTime: json['reading_time'] is int
          ? json['reading_time']
          : int.tryParse('${json['reading_time']}') ?? 1,
      views: json['views'] is int ? json['views'] : int.tryParse('${json['views']}') ?? 0,
      isFeatured: json['is_featured'] == true,
      publishedAt: json['published_at'] != null
          ? DateTime.tryParse(json['published_at'].toString())
          : null,
      url: json['url']?.toString() ?? '',
      blocks: (json['blocks'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(BlogBlock.fromJson)
              .toList() ??
          const [],
      faqs: (json['faqs'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(BlogFaq.fromJson)
              .toList() ??
          const [],
      related: (json['related'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(BlogArticleModel.fromJson)
              .toList() ??
          const [],
    );
  }

  /// "12 Aug 2026" - short, and safe when the date is missing.
  String get publishedLabel {
    final date = publishedAt;
    if (date == null) return '';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

/// A page of articles plus the paging info the list screen needs.
class BlogPage {
  final List<BlogArticleModel> articles;
  final int currentPage;
  final int lastPage;
  final bool hasMore;
  final int total;

  BlogPage({
    required this.articles,
    this.currentPage = 1,
    this.lastPage = 1,
    this.hasMore = false,
    this.total = 0,
  });

  factory BlogPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};

    return BlogPage(
      articles: (json['data'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(BlogArticleModel.fromJson)
              .toList() ??
          const [],
      currentPage: meta['current_page'] is int ? meta['current_page'] : 1,
      lastPage: meta['last_page'] is int ? meta['last_page'] : 1,
      hasMore: meta['has_more'] == true,
      total: meta['total'] is int ? meta['total'] : 0,
    );
  }
}
