import 'package:meta/meta.dart';

@immutable
class Post {
  const Post({
    required this.id,
    required this.title,
    required this.body,
    required this.userId,
  });

  final int id;
  final String title;
  final String body;
  final int userId;

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      userId: json['userId'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'userId': userId,
    };
  }

  Post copyWith({
    int? id,
    String? title,
    String? body,
    int? userId,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      userId: userId ?? this.userId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Post &&
          other.id == id &&
          other.title == title &&
          other.body == body &&
          other.userId == userId);

  @override
  int get hashCode => Object.hash(id, title, body, userId);

  @override
  String toString() => 'Post(id: $id, title: $title, body: $body, userId: $userId)';
}

@immutable
class PostPage {
  const PostPage({
    required this.posts,
    required this.page,
    required this.hasMore,
  });

  final List<Post> posts;
  final int page;
  final bool hasMore;

  factory PostPage.fromJson(Map<String, dynamic> json) {
    return PostPage(
      posts: (json['posts'] as List<dynamic>)
          .map((item) => Post.fromJson(item as Map<String, dynamic>))
          .toList(),
      page: json['page'] as int,
      hasMore: json['hasMore'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'posts': posts.map((post) => post.toJson()).toList(),
      'page': page,
      'hasMore': hasMore,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PostPage &&
          other.posts == posts &&
          other.page == page &&
          other.hasMore == hasMore);

  @override
  int get hashCode => Object.hash(posts, page, hasMore);

  @override
  String toString() => 'PostPage(posts: ${posts.length}, page: $page, hasMore: $hasMore)';
}
