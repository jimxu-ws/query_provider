import 'package:query_provider/query_provider.dart';
import '../models/post.dart';
import '../services/api_service.dart';

/// Async infinite query provider for fetching posts with pagination
final asyncPostsInfiniteQueryProvider = asyncInfiniteQueryProvider<PostPage, int>(
  name: 'async-posts-infinite',
  queryFn: (ref, pageParam) => ApiService.fetchPosts(page: pageParam),
  initialPageParam: 1,
  options: InfiniteQueryOptions<PostPage, int>(
    getNextPageParam: (lastPage, allPages) {
      return lastPage.hasMore ? lastPage.page + 1 : null;
    },
    staleTime: const Duration(minutes: 2),
    cacheTime: const Duration(minutes: 10),
    refetchOnAppFocus: true,
    refetchOnWindowFocus: true,
    pauseRefetchInBackground: true,
    keepPreviousData: true, // Show stale data while fetching fresh data
  ),
);

/// Async infinite query provider without keepPreviousData for comparison
final asyncPostsInfiniteQueryProviderNoKeepPrevious = asyncInfiniteQueryProvider<PostPage, int>(
  name: 'async-posts-infinite-no-keep-previous',
  queryFn: (ref, pageParam) => ApiService.fetchPosts(page: pageParam),
  initialPageParam: 1,
  options: InfiniteQueryOptions<PostPage, int>(
    getNextPageParam: (lastPage, allPages) {
      return lastPage.hasMore ? lastPage.page + 1 : null;
    },
    staleTime: const Duration(seconds: 5), // Short stale time to demonstrate the difference
    cacheTime: const Duration(minutes: 10),
    refetchOnAppFocus: true,
    refetchOnWindowFocus: true,
    pauseRefetchInBackground: true,
    keepPreviousData: false, // Show loading state while fetching fresh data
  ),
);
