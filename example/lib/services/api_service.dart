import 'dart:async';
import 'dart:math';

import '../models/user.dart';
import '../models/post.dart';

/// Mock API service that simulates network requests
class ApiService {
  static const _baseDelay = Duration(milliseconds: 500);
  static const _maxDelay = Duration(milliseconds: 2000);
  static final _random = Random();

  /// Simulate network delay
  static Future<void> _delay() async {
    final delay = _baseDelay + Duration(
      milliseconds: _random.nextInt(_maxDelay.inMilliseconds - _baseDelay.inMilliseconds),
    );
    await Future.delayed(delay);
  }

  /// Simulate random failures (10% chance)
  static void _maybeThrow() {
    if (_random.nextDouble() < 0.1) {
      throw Exception('Random API failure');
    }
  }

  /// Fetch all users
  static Future<List<User>> fetchUsers() async {
    await _delay();
    _maybeThrow();

    return List.generate(10, (index) {
      return User(
        id: index + 1,
        name: 'User ${index + 1}',
        email: 'user${index + 1}@example.com',
        avatar: 'https://i.pravatar.cc/150?img=${index + 1}',
      );
    });
  }

  /// Fetch a single user by ID
  static Future<User> fetchUser(int id) async {
    await _delay();
    _maybeThrow();

    return User(
      id: id,
      name: 'User $id',
      email: 'user$id@example.com',
      avatar: 'https://i.pravatar.cc/150?img=$id',
    );
  }

  /// Search users by name
  static Future<List<User>> searchUsers(String query) async {
    await _delay();
    _maybeThrow();

    if (query.isEmpty) {
      return [];
    }

    // Simulate search results
    return List.generate(5, (index) {
      final userId = query.hashCode.abs() % 1000 + index;
      return User(
        id: userId,
        name: 'User matching "$query" #${index + 1}',
        email: 'user$userId@example.com',
        avatar: 'https://i.pravatar.cc/150?img=$userId',
      );
    });
  }

  /// Create a new user
  static Future<User> createUser(Map<String, dynamic> userData) async {
    await _delay();
    _maybeThrow();

    return User(
      id: _random.nextInt(1000) + 100,
      name: userData['name'] as String,
      email: userData['email'] as String,
      avatar: userData['avatar'] as String?,
    );
  }

  /// Update an existing user
  static Future<User> updateUser(int id, Map<String, dynamic> userData) async {
    await _delay();
    _maybeThrow();

    return User(
      id: id,
      name: userData['name'] as String,
      email: userData['email'] as String,
      avatar: userData['avatar'] as String?,
    );
  }

  /// Delete a user
  static Future<void> deleteUser(int id) async {
    await _delay();
    _maybeThrow();
    // Simulate successful deletion
  }

  /// Fetch posts with pagination
  static Future<PostPage> fetchPosts({int page = 1, int limit = 10}) async {
    await _delay();
    _maybeThrow();

    final startIndex = (page - 1) * limit;
    final totalPosts = 100; // Simulate 100 total posts
    
    final posts = List.generate(
      limit,
      (index) {
        final postId = startIndex + index + 1;
        if (postId > totalPosts) return null;
        
        return Post(
          id: postId,
          title: 'Post $postId Title',
          body: 'This is the body content for post $postId. It contains some interesting information about various topics.',
          userId: (postId % 10) + 1,
        );
      },
    ).where((post) => post != null).cast<Post>().toList();

    final hasMore = startIndex + limit < totalPosts;

    return PostPage(
      posts: posts,
      page: page,
      hasMore: hasMore,
    );
  }

  /// Fetch posts by user ID
  static Future<List<Post>> fetchUserPosts(int userId) async {
    await _delay();
    _maybeThrow();

    return List.generate(5, (index) {
      final postId = (userId * 10) + index + 1;
      return Post(
        id: postId,
        title: 'User $userId Post ${index + 1}',
        body: 'This is post ${index + 1} by user $userId.',
        userId: userId,
      );
    });
  }

  /// Create a new post
  static Future<Post> createPost(Map<String, dynamic> postData) async {
    await _delay();
    _maybeThrow();

    return Post(
      id: _random.nextInt(1000) + 1000,
      title: postData['title'] as String,
      body: postData['body'] as String,
      userId: postData['userId'] as int,
    );
  }

  /// Update an existing post
  static Future<Post> updatePost(int id, Map<String, dynamic> postData) async {
    await _delay();
    _maybeThrow();

    return Post(
      id: id,
      title: postData['title'] as String,
      body: postData['body'] as String,
      userId: postData['userId'] as int,
    );
  }

  /// Delete a post
  static Future<void> deletePost(int id) async {
    await _delay();
    _maybeThrow();
    // Simulate successful deletion
  }

  /// Fetch active users
  static Future<List<User>> fetchActiveUsers() async {
    await _delay();
    _maybeThrow();
    
    // Return a subset of users as "active"
    final allUsers = await fetchUsers();
    return allUsers.take(3).toList(); // Simulate first 3 users as active
  }
}
