class PinnedPost {
  final String id;
  final String title;
  final String content;
  final String category;
  final DateTime createdAt;

  PinnedPost({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.createdAt,
  });

  String get formattedDate {
    return 'Posted on ${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}';
  }
}