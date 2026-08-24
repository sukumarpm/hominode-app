// lib/src/models/notice.dart
// Notice model with priority levels

enum NoticePriority { high, medium, low }

class Notice {
  final String id;
  final String title;
  final String excerpt;
  final String fullContent;
  final DateTime date;
  final NoticePriority priority;

  Notice({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.fullContent,
    required this.date,
    required this.priority,
  });

  factory Notice.fromJson(Map<String, dynamic> json) {
    return Notice(
      id: json['id'] as String,
      title: json['title'] as String,
      excerpt: json['excerpt'] as String,
      fullContent: json['fullContent'] as String,
      date: DateTime.parse(json['date'] as String),
      priority: NoticePriority.values.firstWhere(
        (e) => e.name == json['priority'],
        orElse: () => NoticePriority.medium,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'excerpt': excerpt,
      'fullContent': fullContent,
      'date': date.toIso8601String(),
      'priority': priority.name,
    };
  }

  String get formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
