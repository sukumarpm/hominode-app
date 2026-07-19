// lib/src/models/post.dart
// Community post model

class Post {
  final String id;
  final String authorName;
  final String profileImage;
  final String flat;
  final String timeAgo;
  final String content;
  final String? imageUrl; // Single image (for backward compatibility)
  final List<String>? imageUrls; // Multiple images
  int likes;
  final int comments;
  bool isLiked;
  final bool isMine;

  Post({
    required this.id,
    required this.authorName,
    required this.profileImage,
    required this.flat,
    required this.timeAgo,
    required this.content,
    this.imageUrl,
    this.imageUrls,
    required this.likes,
    required this.comments,
    this.isLiked = false,
    this.isMine = false,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      authorName: json['authorName'] as String,
      profileImage: json['profileImage'] as String,
      flat: json['flat'] as String,
      timeAgo: json['timeAgo'] as String,
      content: json['content'] as String,
      imageUrl: json['imageUrl'] as String?,
      imageUrls: json['imageUrls'] != null
          ? List<String>.from(json['imageUrls'] as List)
          : null,
      likes: json['likes'] as int,
      comments: json['comments'] as int,
      isLiked: json['isLiked'] as bool? ?? false,
      isMine: json['isMine'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorName': authorName,
      'profileImage': profileImage,
      'flat': flat,
      'timeAgo': timeAgo,
      'content': content,
      'imageUrl': imageUrl,
      'imageUrls': imageUrls,
      'likes': likes,
      'comments': comments,
      'isLiked': isLiked,
      'isMine': isMine,
    };
  }

  Post copyWith({
    String? id,
    String? authorName,
    String? profileImage,
    String? flat,
    String? timeAgo,
    String? content,
    String? imageUrl,
    List<String>? imageUrls,
    int? likes,
    int? comments,
    bool? isLiked,
    bool? isMine,
  }) {
    return Post(
      id: id ?? this.id,
      authorName: authorName ?? this.authorName,
      profileImage: profileImage ?? this.profileImage,
      flat: flat ?? this.flat,
      timeAgo: timeAgo ?? this.timeAgo,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      imageUrls: imageUrls ?? this.imageUrls,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
      isLiked: isLiked ?? this.isLiked,
      isMine: isMine ?? this.isMine,
    );
  }
}
