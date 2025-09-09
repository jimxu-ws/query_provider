import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';
import '../models/post.dart';
import '../services/api_service.dart';

/// Unified state that manages both query data and mutation states
class PostsState {
  const PostsState({
    required this.infiniteQueryState,
    required this.createMutationState,
    required this.updateMutationState,
    required this.deleteMutationState,
    this.userPostsCache = const {},
  });

  final InfiniteQueryState<PostPage> infiniteQueryState;
  final MutationState<Post> createMutationState;
  final MutationState<Post> updateMutationState;
  final MutationState<void> deleteMutationState;
  final Map<int, List<Post>> userPostsCache; // Cache user posts by userId

  PostsState copyWith({
    InfiniteQueryState<PostPage>? infiniteQueryState,
    MutationState<Post>? createMutationState,
    MutationState<Post>? updateMutationState,
    MutationState<void>? deleteMutationState,
    Map<int, List<Post>>? userPostsCache,
  }) {
    return PostsState(
      infiniteQueryState: infiniteQueryState ?? this.infiniteQueryState,
      createMutationState: createMutationState ?? this.createMutationState,
      updateMutationState: updateMutationState ?? this.updateMutationState,
      deleteMutationState: deleteMutationState ?? this.deleteMutationState,
      userPostsCache: userPostsCache ?? this.userPostsCache,
    );
  }

  /// Get all posts from all pages
  List<Post> get allPosts {
    return switch (infiniteQueryState) {
      InfiniteQuerySuccess<PostPage> success => success.pages.expand((page) => page.posts).toList(),
      InfiniteQueryFetchingNextPage<PostPage> fetching => fetching.pages.expand((page) => page.posts).toList(),
      InfiniteQueryFetchingPreviousPage<PostPage> fetching => fetching.pages.expand((page) => page.posts).toList(),
      _ => [],
    };
  }

  /// Check if any mutation is loading
  bool get isAnyMutationLoading {
    return createMutationState.isLoading ||
           updateMutationState.isLoading ||
           deleteMutationState.isLoading;
  }
}

/// Unified provider that manages all post operations
class UnifiedPostsNotifier extends StateNotifier<PostsState> {
  UnifiedPostsNotifier(this._ref) : super(PostsState(
    infiniteQueryState: InfiniteQueryIdle<PostPage>(),
    createMutationState: MutationIdle<Post>(),
    updateMutationState: MutationIdle<Post>(),
    deleteMutationState: MutationIdle<void>(),
  )) {
    _initializeInfiniteQuery();
  }

  final Ref _ref;
  
  // Internal infinite query notifier
  late final InfiniteQueryNotifier<PostPage, int> _infiniteQueryNotifier;

  void _initializeInfiniteQuery() {
    _infiniteQueryNotifier = InfiniteQueryNotifier<PostPage, int>(
      queryKey: 'posts-infinite',
      queryFn: (pageParam) => ApiService.fetchPosts(page: pageParam),
      initialPageParam: 1,
      options: InfiniteQueryOptions<PostPage, int>(
        getNextPageParam: (lastPage, allPages) {
          return lastPage.hasMore ? lastPage.page + 1 : null;
        },
        staleTime: const Duration(minutes: 2),
        cacheTime: const Duration(minutes: 10),
      ),
    );

    // Listen to infinite query state changes
    _infiniteQueryNotifier.addListener((queryState) {
      state = state.copyWith(infiniteQueryState: queryState);
    });
  }

  /// Fetch initial posts (triggers automatic fetch on first access)
  Future<void> fetchPosts() async {
    // The infinite query notifier automatically fetches on initialization
    // if refetchOnMount is true (which is the default)
    if (state.infiniteQueryState is InfiniteQueryIdle) {
      await _infiniteQueryNotifier.refetch();
    }
  }

  /// Fetch next page
  Future<void> fetchNextPage() async {
    await _infiniteQueryNotifier.fetchNextPage();
  }

  /// Refetch all posts
  Future<void> refetch() async {
    await _infiniteQueryNotifier.refetch();
  }

  /// Fetch user posts
  Future<List<Post>> fetchUserPosts(int userId) async {
    // Check cache first
    if (state.userPostsCache.containsKey(userId)) {
      return state.userPostsCache[userId]!;
    }

    try {
      final posts = await ApiService.fetchUserPosts(userId);
      
      // Update cache
      final updatedCache = Map<int, List<Post>>.from(state.userPostsCache);
      updatedCache[userId] = posts;
      state = state.copyWith(userPostsCache: updatedCache);
      
      return posts;
    } catch (error) {
      rethrow;
    }
  }

  /// Create a new post with optimistic updates
  Future<Post> createPost(Map<String, dynamic> variables) async {
    // Set loading state
    state = state.copyWith(createMutationState: MutationLoading<Post>());

    try {
      // Optimistic update
      final optimisticPost = Post(
        id: -DateTime.now().millisecondsSinceEpoch,
        title: variables['title'] as String,
        body: variables['body'] as String,
        userId: variables['userId'] as int,
      );

      _addOptimisticPost(optimisticPost);

      // Make API call
      final realPost = await ApiService.createPost(variables);

      // Replace optimistic post with real post
      _replaceOptimisticPost(optimisticPost, realPost);

      // Update success state
      state = state.copyWith(createMutationState: MutationSuccess(realPost));

      return realPost;
    } catch (error, stackTrace) {
      // Remove optimistic post on error
      _removeOptimisticPosts();

      // Update error state
      state = state.copyWith(
        createMutationState: MutationError<Post>(error, stackTrace: stackTrace),
      );

      rethrow;
    }
  }

  /// Update a post with optimistic updates
  Future<Post> updatePost(int postId, Map<String, dynamic> variables) async {
    // Set loading state
    state = state.copyWith(updateMutationState: MutationLoading<Post>());

    // Store original post for rollback
    Post? originalPost;

    try {
      // Find and update post optimistically
      originalPost = _updatePostOptimistically(postId, variables);

      // Make API call
      final updatedPost = await ApiService.updatePost(postId, variables);

      // Replace optimistic update with real data
      _replacePost(postId, updatedPost);

      // Update success state
      state = state.copyWith(updateMutationState: MutationSuccess(updatedPost));

      return updatedPost;
    } catch (error, stackTrace) {
      // Rollback optimistic update
      if (originalPost != null) {
        _replacePost(postId, originalPost);
      }

      // Update error state
      state = state.copyWith(
        updateMutationState: MutationError<Post>(error, stackTrace: stackTrace),
      );

      rethrow;
    }
  }

  /// Delete a post with optimistic updates
  Future<void> deletePost(int postId) async {
    // Set loading state
    state = state.copyWith(deleteMutationState: MutationLoading<void>());

    // Store original post for rollback
    Post? originalPost;
    int? originalPageIndex;
    int? originalPostIndex;

    try {
      // Remove post optimistically and store original data
      final removeResult = _removePostOptimistically(postId);
      originalPost = removeResult['post'] as Post?;
      originalPageIndex = removeResult['pageIndex'] as int?;
      originalPostIndex = removeResult['postIndex'] as int?;

      // Make API call
      await ApiService.deletePost(postId);

      // Update success state
      state = state.copyWith(deleteMutationState: MutationSuccess(null));
    } catch (error, stackTrace) {
      // Rollback optimistic update
      if (originalPost != null && originalPageIndex != null && originalPostIndex != null) {
        _restoreDeletedPost(originalPost, originalPageIndex, originalPostIndex);
      }

      // Update error state
      state = state.copyWith(
        deleteMutationState: MutationError<void>(error, stackTrace: stackTrace),
      );

      rethrow;
    }
  }

  /// Reset mutation states
  void resetCreateMutation() {
    state = state.copyWith(createMutationState: MutationIdle<Post>());
  }

  void resetUpdateMutation() {
    state = state.copyWith(updateMutationState: MutationIdle<Post>());
  }

  void resetDeleteMutation() {
    state = state.copyWith(deleteMutationState: MutationIdle<void>());
  }

  // Helper methods for optimistic updates
  void _addOptimisticPost(Post post) {
    if (state.infiniteQueryState case InfiniteQuerySuccess<PostPage> success) {
      if (success.pages.isNotEmpty) {
        final firstPage = success.pages[0];
        final updatedPosts = [post, ...firstPage.posts];
        final updatedFirstPage = PostPage(
          posts: updatedPosts,
          page: firstPage.page,
          hasMore: firstPage.hasMore,
        );
        final updatedPages = [...success.pages];
        updatedPages[0] = updatedFirstPage;

        state = state.copyWith(
          infiniteQueryState: InfiniteQuerySuccess(
            pages: updatedPages,
            hasNextPage: success.hasNextPage,
            hasPreviousPage: success.hasPreviousPage,
            fetchedAt: success.fetchedAt,
          ),
        );
      }
    }
  }

  void _replaceOptimisticPost(Post optimisticPost, Post realPost) {
    if (state.infiniteQueryState case InfiniteQuerySuccess<PostPage> success) {
      final updatedPages = success.pages.map((page) {
        final updatedPosts = page.posts.map((p) {
          return p.id == optimisticPost.id ? realPost : p;
        }).toList();
        return PostPage(
          posts: updatedPosts,
          page: page.page,
          hasMore: page.hasMore,
        );
      }).toList();

      state = state.copyWith(
        infiniteQueryState: InfiniteQuerySuccess(
          pages: updatedPages,
          hasNextPage: success.hasNextPage,
          hasPreviousPage: success.hasPreviousPage,
          fetchedAt: success.fetchedAt,
        ),
      );
    }
  }

  void _removeOptimisticPosts() {
    if (state.infiniteQueryState case InfiniteQuerySuccess<PostPage> success) {
      final updatedPages = success.pages.map((page) {
        final updatedPosts = page.posts.where((p) => p.id >= 0).toList();
        return PostPage(
          posts: updatedPosts,
          page: page.page,
          hasMore: page.hasMore,
        );
      }).toList();

      state = state.copyWith(
        infiniteQueryState: InfiniteQuerySuccess(
          pages: updatedPages,
          hasNextPage: success.hasNextPage,
          hasPreviousPage: success.hasPreviousPage,
          fetchedAt: success.fetchedAt,
        ),
      );
    }
  }

  Post? _updatePostOptimistically(int postId, Map<String, dynamic> variables) {
    Post? originalPost;

    if (state.infiniteQueryState case InfiniteQuerySuccess<PostPage> success) {
      final updatedPages = success.pages.map((page) {
        final updatedPosts = page.posts.map((post) {
          if (post.id == postId) {
            originalPost = post;
            return post.copyWith(
              title: variables['title'] as String?,
              body: variables['body'] as String?,
            );
          }
          return post;
        }).toList();
        return PostPage(
          posts: updatedPosts,
          page: page.page,
          hasMore: page.hasMore,
        );
      }).toList();

      state = state.copyWith(
        infiniteQueryState: InfiniteQuerySuccess(
          pages: updatedPages,
          hasNextPage: success.hasNextPage,
          hasPreviousPage: success.hasPreviousPage,
          fetchedAt: success.fetchedAt,
        ),
      );
    }

    return originalPost;
  }

  void _replacePost(int postId, Post newPost) {
    if (state.infiniteQueryState case InfiniteQuerySuccess<PostPage> success) {
      final updatedPages = success.pages.map((page) {
        final updatedPosts = page.posts.map((post) {
          return post.id == postId ? newPost : post;
        }).toList();
        return PostPage(
          posts: updatedPosts,
          page: page.page,
          hasMore: page.hasMore,
        );
      }).toList();

      state = state.copyWith(
        infiniteQueryState: InfiniteQuerySuccess(
          pages: updatedPages,
          hasNextPage: success.hasNextPage,
          hasPreviousPage: success.hasPreviousPage,
          fetchedAt: success.fetchedAt,
        ),
      );
    }

    // Also update user posts cache
    final updatedUserCache = Map<int, List<Post>>.from(state.userPostsCache);
    updatedUserCache.forEach((userId, posts) {
      final postIndex = posts.indexWhere((p) => p.id == postId);
      if (postIndex != -1) {
        posts[postIndex] = newPost;
      }
    });
    state = state.copyWith(userPostsCache: updatedUserCache);
  }

  Map<String, dynamic> _removePostOptimistically(int postId) {
    Post? removedPost;
    int? pageIndex;
    int? postIndex;

    if (state.infiniteQueryState case InfiniteQuerySuccess<PostPage> success) {
      final updatedPages = <PostPage>[];
      
      for (int i = 0; i < success.pages.length; i++) {
        final page = success.pages[i];
        final postIdx = page.posts.indexWhere((p) => p.id == postId);
        
        if (postIdx != -1) {
          removedPost = page.posts[postIdx];
          pageIndex = i;
          postIndex = postIdx;
          
          final updatedPosts = List<Post>.from(page.posts);
          updatedPosts.removeAt(postIdx);
          
          updatedPages.add(PostPage(
            posts: updatedPosts,
            page: page.page,
            hasMore: page.hasMore,
          ));
        } else {
          updatedPages.add(page);
        }
      }

      state = state.copyWith(
        infiniteQueryState: InfiniteQuerySuccess(
          pages: updatedPages,
          hasNextPage: success.hasNextPage,
          hasPreviousPage: success.hasPreviousPage,
          fetchedAt: success.fetchedAt,
        ),
      );
    }

    // Also remove from user posts cache
    if (removedPost != null) {
      final updatedUserCache = Map<int, List<Post>>.from(state.userPostsCache);
      updatedUserCache.forEach((userId, posts) {
        posts.removeWhere((p) => p.id == postId);
      });
      state = state.copyWith(userPostsCache: updatedUserCache);
    }

    return {
      'post': removedPost,
      'pageIndex': pageIndex,
      'postIndex': postIndex,
    };
  }

  void _restoreDeletedPost(Post post, int pageIndex, int postIndex) {
    if (state.infiniteQueryState case InfiniteQuerySuccess<PostPage> success) {
      if (pageIndex < success.pages.length) {
        final updatedPages = List<PostPage>.from(success.pages);
        final page = updatedPages[pageIndex];
        final updatedPosts = List<Post>.from(page.posts);
        updatedPosts.insert(postIndex, post);
        
        updatedPages[pageIndex] = PostPage(
          posts: updatedPosts,
          page: page.page,
          hasMore: page.hasMore,
        );

        state = state.copyWith(
          infiniteQueryState: InfiniteQuerySuccess(
            pages: updatedPages,
            hasNextPage: success.hasNextPage,
            hasPreviousPage: success.hasPreviousPage,
            fetchedAt: success.fetchedAt,
          ),
        );
      }
    }

    // Restore in user posts cache
    final updatedUserCache = Map<int, List<Post>>.from(state.userPostsCache);
    if (updatedUserCache.containsKey(post.userId)) {
      updatedUserCache[post.userId]!.add(post);
    }
    state = state.copyWith(userPostsCache: updatedUserCache);
  }

  @override
  void dispose() {
    _infiniteQueryNotifier.dispose();
    super.dispose();
  }
}

/// The unified posts provider
final unifiedPostsProvider = StateNotifierProvider<UnifiedPostsNotifier, PostsState>((ref) {
  return UnifiedPostsNotifier(ref);
});

/// Convenience providers for specific aspects
final postsQueryStateProvider = Provider<InfiniteQueryState<PostPage>>((ref) {
  return ref.watch(unifiedPostsProvider).infiniteQueryState;
});

final createPostMutationStateProvider = Provider<MutationState<Post>>((ref) {
  return ref.watch(unifiedPostsProvider).createMutationState;
});

final updatePostMutationStateProvider = Provider<MutationState<Post>>((ref) {
  return ref.watch(unifiedPostsProvider).updateMutationState;
});

final deletePostMutationStateProvider = Provider<MutationState<void>>((ref) {
  return ref.watch(unifiedPostsProvider).deleteMutationState;
});

final allPostsProvider = Provider<List<Post>>((ref) {
  return ref.watch(unifiedPostsProvider).allPosts;
});

final isAnyMutationLoadingProvider = Provider<bool>((ref) {
  return ref.watch(unifiedPostsProvider).isAnyMutationLoading;
});
