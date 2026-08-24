// lib/src/models/comment.dart
// Comment model for community posts

class Comment {
  final String id;
  final String postId;
  final String authorName;
  final String profileImage;
  final String content;
  final String timeAgo;
  final bool isMine;

  Comment({
    required this.id,
    required this.postId,
    required this.authorName,
    required this.profileImage,
    required this.content,
    required this.timeAgo,
    this.isMine = false,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['id'] as String,
      postId: json['postId'] as String,
      authorName: json['authorName'] as String,
      profileImage: json['profileImage'] as String,
      content: json['content'] as String,
      timeAgo: json['timeAgo'] as String,
      isMine: json['isMine'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'authorName': authorName,
      'profileImage': profileImage,
      'content': content,
      'timeAgo': timeAgo,
      'isMine': isMine,
    };
  }
}
