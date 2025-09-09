import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';
import '../models/post.dart';
import '../services/api_service.dart';

/// Infinite query provider for fetching posts with pagination
final postsInfiniteQueryProvider = infiniteQueryProvider<PostPage, int>(
  name: 'posts-infinite',
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

/// Query provider for fetching posts by user ID
StateNotifierProvider<QueryNotifier<List<Post>>, QueryState<List<Post>>> userPostsQueryProvider(int userId) {
  return queryProvider<List<Post>>(
    name: 'user-posts-$userId',
    queryFn: () => ApiService.fetchUserPosts(userId),
    options: const QueryOptions<List<Post>>(
      staleTime: Duration(minutes: 3),
      cacheTime: Duration(minutes: 10),
    ),
  );
}

/// Mutation provider for creating a new post
final createPostMutationProvider = StateNotifierProvider<MutationNotifier<Post, Map<String, dynamic>>, MutationState<Post>>((ref) {
  return MutationNotifier<Post, Map<String, dynamic>>(
    mutationFn: ApiService.createPost,
    options: MutationOptions<Post, Map<String, dynamic>>(
      onMutate: (variables) async {
        final queryClient = ref.read(queryClientProvider);
        
        // Create optimistic post with temporary ID
        final optimisticPost = Post(
          id: -DateTime.now().millisecondsSinceEpoch, // Negative ID for temp posts
          title: variables['title'] as String,
          body: variables['body'] as String,
          userId: variables['userId'] as int,
        );
        
        // Get current infinite query data
        final infiniteQueryEntry = queryClient.getCacheEntry<List<PostPage>>('posts-infinite');
        if (infiniteQueryEntry?.hasData == true) {
          final currentPages = List<PostPage>.from(infiniteQueryEntry!.data!);
          
          // Add optimistic post to the first page
          if (currentPages.isNotEmpty) {
            final firstPage = currentPages[0];
            final updatedPosts = [optimisticPost, ...firstPage.posts];
            final updatedFirstPage = PostPage(
              posts: updatedPosts,
              page: firstPage.page,
              hasMore: firstPage.hasMore,
            );
            currentPages[0] = updatedFirstPage;
            
            // Update cache with optimistic data
            queryClient.setQueryData('posts-infinite', currentPages);
          }
        }
        
        // Note: Original data stored in cache for potential rollback via invalidation
      },
      onSuccess: (post, variables) {
        print('Post created successfully: ${post.title}');
        
        final queryClient = ref.read(queryClientProvider);
        
        // Replace optimistic post with real post data
        final infiniteQueryEntry = queryClient.getCacheEntry<List<PostPage>>('posts-infinite');
        if (infiniteQueryEntry?.hasData == true) {
          final currentPages = List<PostPage>.from(infiniteQueryEntry!.data!);
          
          if (currentPages.isNotEmpty) {
            final firstPage = currentPages[0];
            // Remove optimistic post (negative ID) and add real post
            final updatedPosts = firstPage.posts
                .where((p) => p.id >= 0) // Remove optimistic posts
                .toList();
            updatedPosts.insert(0, post); // Add real post at the beginning
            
            final updatedFirstPage = PostPage(
              posts: updatedPosts,
              page: firstPage.page,
              hasMore: firstPage.hasMore,
            );
            currentPages[0] = updatedFirstPage;
            
            queryClient.setQueryData('posts-infinite', currentPages);
          }
        }
      },
      onError: (error, variables, stackTrace) {
        print('Failed to create post: $error');
        
        // Rollback optimistic update
        final queryClient = ref.read(queryClientProvider);
        final infiniteQueryEntry = queryClient.getCacheEntry<List<PostPage>>('posts-infinite');
        if (infiniteQueryEntry?.hasData == true) {
          final currentPages = List<PostPage>.from(infiniteQueryEntry!.data!);
          
          if (currentPages.isNotEmpty) {
            final firstPage = currentPages[0];
            // Remove optimistic posts (negative IDs)
            final rollbackPosts = firstPage.posts
                .where((p) => p.id >= 0)
                .toList();
            
            final rollbackFirstPage = PostPage(
              posts: rollbackPosts,
              page: firstPage.page,
              hasMore: firstPage.hasMore,
            );
            currentPages[0] = rollbackFirstPage;
            
            queryClient.setQueryData('posts-infinite', currentPages);
          }
        }
      },
    ),
  );
});

/// Mutation provider family for updating a post
final updatePostMutationProvider = StateNotifierProvider.family<MutationNotifier<Post, Map<String, dynamic>>, MutationState<Post>, int>((ref, postId) {
  return MutationNotifier<Post, Map<String, dynamic>>(
    mutationFn: (variables) => ApiService.updatePost(postId, variables),
    options: MutationOptions<Post, Map<String, dynamic>>(
      onMutate: (variables) async {
        final queryClient = ref.read(queryClientProvider);
        
        // Store original data for rollback
        final originalInfiniteData = queryClient.getCacheEntry<List<PostPage>>('posts-infinite')?.data;
        final originalUserPostsData = queryClient.getCacheEntry<List<Post>>('user-posts-${variables['userId']}')?.data;
        
        // Update post in infinite query cache
        final infiniteQueryEntry = queryClient.getCacheEntry<List<PostPage>>('posts-infinite');
        if (infiniteQueryEntry?.hasData == true) {
          final currentPages = List<PostPage>.from(infiniteQueryEntry!.data!);
          
          for (int pageIndex = 0; pageIndex < currentPages.length; pageIndex++) {
            final page = currentPages[pageIndex];
            final postIndex = page.posts.indexWhere((p) => p.id == postId);
            
            if (postIndex != -1) {
              // Create optimistically updated post
              final originalPost = page.posts[postIndex];
              final optimisticPost = originalPost.copyWith(
                title: variables['title'] as String?,
                body: variables['body'] as String?,
              );
              
              // Update the post in the page
              final updatedPosts = List<Post>.from(page.posts);
              updatedPosts[postIndex] = optimisticPost;
              
              final updatedPage = PostPage(
                posts: updatedPosts,
                page: page.page,
                hasMore: page.hasMore,
              );
              currentPages[pageIndex] = updatedPage;
              
              queryClient.setQueryData('posts-infinite', currentPages);
              break;
            }
          }
        }
        
        // Update post in user posts cache if it exists
        final userPostsEntry = queryClient.getCacheEntry<List<Post>>('user-posts-${variables['userId']}');
        if (userPostsEntry?.hasData == true) {
          final currentUserPosts = List<Post>.from(userPostsEntry!.data!);
          final postIndex = currentUserPosts.indexWhere((p) => p.id == postId);
          
          if (postIndex != -1) {
            final originalPost = currentUserPosts[postIndex];
            final optimisticPost = originalPost.copyWith(
              title: variables['title'] as String?,
              body: variables['body'] as String?,
            );
            currentUserPosts[postIndex] = optimisticPost;
            queryClient.setQueryData('user-posts-${variables['userId']}', currentUserPosts);
          }
        }
        
        // Note: Original data stored for potential rollback via invalidation
      },
      onSuccess: (post, variables) {
        print('Post updated successfully: ${post.title}');
        
        final queryClient = ref.read(queryClientProvider);
        
        // Replace optimistic data with real server data
        // Update infinite query cache
        final infiniteQueryEntry = queryClient.getCacheEntry<List<PostPage>>('posts-infinite');
        if (infiniteQueryEntry?.hasData == true) {
          final currentPages = List<PostPage>.from(infiniteQueryEntry!.data!);
          
          for (int pageIndex = 0; pageIndex < currentPages.length; pageIndex++) {
            final page = currentPages[pageIndex];
            final postIndex = page.posts.indexWhere((p) => p.id == postId);
            
            if (postIndex != -1) {
              final updatedPosts = List<Post>.from(page.posts);
              updatedPosts[postIndex] = post; // Use real server data
              
              final updatedPage = PostPage(
                posts: updatedPosts,
                page: page.page,
                hasMore: page.hasMore,
              );
              currentPages[pageIndex] = updatedPage;
              
              queryClient.setQueryData('posts-infinite', currentPages);
              break;
            }
          }
        }
        
        // Update user posts cache
        final userPostsEntry = queryClient.getCacheEntry<List<Post>>('user-posts-${post.userId}');
        if (userPostsEntry?.hasData == true) {
          final currentUserPosts = List<Post>.from(userPostsEntry!.data!);
          final postIndex = currentUserPosts.indexWhere((p) => p.id == postId);
          
          if (postIndex != -1) {
            currentUserPosts[postIndex] = post;
            queryClient.setQueryData('user-posts-${post.userId}', currentUserPosts);
          }
        }
      },
      onError: (error, variables, stackTrace) {
        print('Failed to update post: $error');
        
        // Rollback optimistic updates
        final queryClient = ref.read(queryClientProvider);
        // Note: In a real implementation, you'd restore from the data returned by onMutate
        // For now, we'll invalidate to refetch fresh data
        queryClient.invalidateQueries('posts');
        queryClient.invalidateQueries('user-posts-${variables['userId']}');
      },
    ),
  );
});

/// Mutation provider family for deleting a post
final deletePostMutationProvider = StateNotifierProvider.family<MutationNotifier<void, int>, MutationState<void>, int>((ref, postId) {
  return MutationNotifier<void, int>(
    mutationFn: (id) => ApiService.deletePost(id),
    options: MutationOptions<void, int>(
      onMutate: (id) async {
        final queryClient = ref.read(queryClientProvider);
        
        // Store original data for rollback
        final originalInfiniteData = queryClient.getCacheEntry<List<PostPage>>('posts-infinite')?.data;
        Post? deletedPost;
        
        // Remove post from infinite query cache
        final infiniteQueryEntry = queryClient.getCacheEntry<List<PostPage>>('posts-infinite');
        if (infiniteQueryEntry?.hasData == true) {
          final currentPages = List<PostPage>.from(infiniteQueryEntry!.data!);
          
          for (int pageIndex = 0; pageIndex < currentPages.length; pageIndex++) {
            final page = currentPages[pageIndex];
            final postIndex = page.posts.indexWhere((p) => p.id == postId);
            
            if (postIndex != -1) {
              deletedPost = page.posts[postIndex];
              
              // Remove the post from the page
              final updatedPosts = List<Post>.from(page.posts);
              updatedPosts.removeAt(postIndex);
              
              final updatedPage = PostPage(
                posts: updatedPosts,
                page: page.page,
                hasMore: page.hasMore,
              );
              currentPages[pageIndex] = updatedPage;
              
              queryClient.setQueryData('posts-infinite', currentPages);
              break;
            }
          }
        }
        
        // Remove post from user posts cache if it exists
        if (deletedPost != null) {
          final userPostsEntry = queryClient.getCacheEntry<List<Post>>('user-posts-${deletedPost.userId}');
          if (userPostsEntry?.hasData == true) {
            final currentUserPosts = List<Post>.from(userPostsEntry!.data!);
            currentUserPosts.removeWhere((p) => p.id == postId);
            queryClient.setQueryData('user-posts-${deletedPost.userId}', currentUserPosts);
          }
        }
        
        // Note: Original data stored for potential rollback via invalidation
      },
      onSuccess: (_, id) {
        print('Post $id deleted successfully');
        // Optimistic update already handled in onMutate
        // No need to refetch - the UI is already updated
      },
      onError: (error, id, stackTrace) {
        print('Failed to delete post $id: $error');
        
        // Rollback optimistic updates
        final queryClient = ref.read(queryClientProvider);
        // Note: In a real implementation, you'd restore from the data returned by onMutate
        // For now, we'll invalidate to refetch fresh data
        queryClient.invalidateQueries('posts');
        queryClient.invalidateQueries('user-posts');
      },
    ),
  );
});
