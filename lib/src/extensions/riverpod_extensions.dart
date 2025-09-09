import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../query_cache.dart';
import '../query_client.dart';
import '../query_options.dart';
import '../query_state.dart';
import '../mutation_options.dart';
import '../query_provider.dart';
import '../mutation_provider.dart';

/// Utility functions for easier integration with @riverpod
class QueryUtils {
  /// Create a query provider from a simple function
  /// 
  /// Example:
  /// ```dart
  /// final usersProvider = QueryUtils.query<List<User>>(
  ///   name: 'users',
  ///   queryFn: () => ApiService.fetchUsers(),
  ///   options: QueryOptions(staleTime: Duration(minutes: 5)),
  /// );
  /// ```
  static StateNotifierProvider<QueryNotifier<T>, QueryState<T>> query<T>({
    required String name,
    required Future<T> Function() queryFn,
    QueryOptions<T>? options,
  }) => queryProvider<T>(
      name: name,
      queryFn: queryFn,
      options: options ?? QueryOptions<T>(),
    );

  /// Create a mutation provider from a simple function
  /// 
  /// Example:
  /// ```dart
  /// final createUserProvider = QueryUtils.mutation<User, Map<String, dynamic>>(
  ///   name: 'create-user',
  ///   mutationFn: (userData) => ApiService.createUser(userData),
  ///   options: MutationOptions(
  ///     onSuccess: (user, _) => print('User created: ${user.name}'),
  ///   ),
  /// );
  /// ```
  static StateNotifierProvider<MutationNotifier<T, TVariables>, MutationState<T>> mutation<T, TVariables>({
    required String name,
    required Future<T> Function(TVariables) mutationFn,
    MutationOptions<T, TVariables>? options,
  }) => mutationProvider<T, TVariables>(
      name: name,
      mutationFn: mutationFn,
      options: options ?? MutationOptions<T, TVariables>(),
    );

  /// Create a cached data fetcher with automatic cache key generation
  /// 
  /// Example:
  /// ```dart
  /// @riverpod
  /// class PayrollCheck extends _$PayrollCheck {
  ///   late final _payrollFetcher = QueryUtils.cachedFetcher<Result<GetPayrollResponse>>(
  ///     ref: ref,
  ///     fetchFn: () => ref.read(apiClientProvider).getPayroll(),
  ///     cacheKey: 'payroll-data', // optional, auto-generated if not provided
  ///   );
  /// 
  ///   Future<void> getPayroll() async {
  ///     await _payrollFetcher.getDataWithCallbacks(
  ///       onData: (result) => _updateState(result),
  ///       onLoading: () => _setLoading(),
  ///       onError: (error) => _setError(error),
  ///     );
  ///   }
  /// }
  /// ```
  static CachedDataFetcher<T> cachedFetcher<T>({
    required Ref ref,
    required Future<T> Function() fetchFn,
    String? cacheKey,
    Duration? cacheDuration,
    bool cacheErrors = false,
  }) {
    return CachedDataFetcher<T>(
      ref: ref,
      fetchFn: fetchFn,
      cacheKey: cacheKey,
      cacheDuration: cacheDuration,
      cacheErrors: cacheErrors,
    );
  }
}

/// Generic cached data fetcher with automatic cache key generation and lifecycle management
/// 
/// This class encapsulates all caching logic and provides a clean API for data fetching
/// with automatic cache management, error handling, and refresh capabilities.
class CachedDataFetcher<T> {
  final Ref ref;
  final String cacheKey;
  final Future<T> Function() fetchFn;
  final Duration? cacheDuration;
  final bool cacheErrors;

  CachedDataFetcher({
    required this.ref,
    required this.fetchFn,
    String? cacheKey,
    this.cacheDuration,
    this.cacheErrors = false,
  }) : cacheKey = cacheKey ?? _generateCacheKey<T>(fetchFn);

  /// Generate automatic cache key based on function and type
  static String _generateCacheKey<T>(Future<T> Function() fetchFn) {
    final typeString = T.toString();
    final functionHash = fetchFn.hashCode.toString();
    return 'cached-data-$typeString-$functionHash';
  }

  /// Get data with automatic caching and staleness checks (original method for backward compatibility)
  /// 
  /// [forceRefresh] - if true, bypasses cache and fetches fresh data
  /// [updateCache] - if false, doesn't update cache with new data (useful for one-time fetches)
  Future<T> getData({
    bool forceRefresh = false,
    bool updateCache = true,
  }) async {
    final queryClient = ref.queryClient;

    // Check cache first (unless force refresh)
    if (!forceRefresh) {
      final cached = queryClient.getQueryData<T>(cacheKey);
      if (cached != null) {
        return cached;
      }
    }

    try {
      // Fetch fresh data
      final result = await fetchFn();
      
      // Cache the successful result
      if (updateCache) {
        queryClient.setQueryData<T>(cacheKey, result);
      }
      
      return result;
    } catch (error) {
      // Optionally cache errors to prevent repeated failed requests
      if (cacheErrors && updateCache) {
        // Store a special error marker in cache (you might want to customize this)
        queryClient.setQueryData<T?>(cacheKey, null);
      }
      rethrow;
    }
  }

  /// Refresh data (invalidate cache and fetch new) - returns the fresh data
  Future<T> refresh() async {
    ref.invalidateQueries(cacheKey);
    return getData(forceRefresh: true);
  }

  /// Clear cache for this data
  void clearCache() {
    ref.removeQueries(cacheKey);
  }

  /// Get cached data without fetching (returns null if not cached)
  T? getCached() {
    return ref.queryClient.getQueryData<T>(cacheKey);
  }

  /// Check if data is currently cached
  bool get isCached => getCached() != null;

  /// Get data if cached, otherwise fetch and cache
  /// This is an alias for getData() with default parameters
  Future<T> getOrFetch() => getData();

}

/// Smart cached data fetcher with stale-while-revalidate strategy
/// 
/// This advanced fetcher implements React Query's stale-while-revalidate pattern:
/// - Returns cached data immediately if available
/// - Fetches fresh data in background
/// - Updates state when fresh data arrives
/// - Supports window focus and background refresh
/// - Handles lifecycle events automatically
class SmartCachedFetcher<T> {
  final dynamic ref; // Accept both Ref and WidgetRef
  final String cacheKey;
  final Future<T> Function() fetchFn;
  final void Function(T data) onData;
  final void Function() onLoading;
  final void Function(Object error) onError;
  final Duration staleTime;
  final Duration cacheTime;
  final bool enableBackgroundRefresh;
  final bool enableWindowFocusRefresh;
  final bool cacheErrors;

  DateTime? _lastFetchTime;
  bool _isCurrentlyFetching = false;
  
  /// Get query client from either Ref or WidgetRef
  QueryClient _getQueryClient() {
    if (ref is Ref) {
      return (ref as Ref).queryClient;
    } else if (ref is WidgetRef) {
      return (ref as WidgetRef).queryClient;
    } else {
      throw StateError('ref must be either Ref or WidgetRef');
    }
  }
  
  
  /// Remove queries safely
  void _removeQueries(String pattern) {
    if (ref is Ref) {
      (ref as Ref).removeQueries(pattern);
    } else if (ref is WidgetRef) {
      (ref as WidgetRef).removeQueries(pattern);
    }
  }

  SmartCachedFetcher({
    required this.ref,
    required this.fetchFn,
    required this.onData,
    required this.onLoading,
    required this.onError,
    String? cacheKey,
    this.staleTime = const Duration(minutes: 5),
    this.cacheTime = const Duration(minutes: 30),
    this.enableBackgroundRefresh = true,
    this.enableWindowFocusRefresh = true,
    this.cacheErrors = false,
  }) : cacheKey = cacheKey ?? _generateCacheKey<T>(fetchFn) {
    _setupLifecycleListeners();
  }

  /// Generate automatic cache key based on function and type
  static String _generateCacheKey<T>(Future<T> Function() fetchFn) {
    final typeString = T.toString();
    final functionHash = fetchFn.hashCode.toString();
    return 'smart-cached-$typeString-$functionHash';
  }

  /// Setup lifecycle listeners for background refresh and window focus
  void _setupLifecycleListeners() {
    if (enableBackgroundRefresh || enableWindowFocusRefresh) {
      // In a real implementation, you would listen to app lifecycle events
      // For now, we'll implement the core logic
    }
  }

  /// Fetch data with stale-while-revalidate strategy
  Future<void> fetch({bool forceRefresh = false}) async {
    final queryClient = _getQueryClient();

    // Check if we have cached data
    final cachedData = queryClient.getQueryData<T>(cacheKey);
    final isStale = _isDataStale();

    // Strategy 1: Return cached data immediately if available and not forcing refresh
    if (cachedData != null && !forceRefresh) {
      // Return cached data immediately
      onData(cachedData);
      
      // If data is stale, fetch fresh data in background
      if (isStale && !_isCurrentlyFetching) {
        _fetchInBackground();
      }
      return;
    }

    // Strategy 2: No cache or forcing refresh - show loading and fetch
    if (cachedData == null || forceRefresh) {
      onLoading();
    }

    await _performFetch();
  }

  /// Check if cached data is stale
  bool _isDataStale() {
    if (_lastFetchTime == null) return true;
    final now = DateTime.now();
    return now.difference(_lastFetchTime!) > staleTime;
  }

  /// Fetch data in background without showing loading state
  void _fetchInBackground() {
    if (_isCurrentlyFetching) {
      return;
    }
    
    _performFetch(showLoading: false).catchError((error) {
      // Silent error handling for background refresh
      // Don't call onError to avoid disrupting user experience
    });
  }

  /// Perform the actual fetch operation
  Future<void> _performFetch({bool showLoading = true}) async {
    if (_isCurrentlyFetching) {
      return;
    }
    
    _isCurrentlyFetching = true;
    final queryClient = _getQueryClient();

    try {
      // Fetch fresh data
      final result = await fetchFn();
      _lastFetchTime = DateTime.now();
      
      // Cache the successful result
      queryClient.setQueryData<T>(cacheKey, result);
      
      // Update state with fresh data
      onData(result);
    } catch (error) {
      // Handle error
      if (cacheErrors) {
        queryClient.setQueryData<T?>(cacheKey, null);
      }
      
      // Only show error if this is not a background refresh
      if (showLoading) {
        onError(error);
      }
    } finally {
      _isCurrentlyFetching = false;
    }
  }

  /// Refresh data (force fresh fetch)
  Future<void> refresh() async {
    await fetch(forceRefresh: true);
  }

  /// Clear cache
  void clearCache() {
    _removeQueries(cacheKey);
    _lastFetchTime = null;
  }

  /// Get cached data without triggering fetch
  T? getCached() {
    return _getQueryClient().getQueryData<T>(cacheKey);
  }

  /// Check if data is cached
  bool get isCached => getCached() != null;

  /// Check if data is stale
  bool get isStale => _isDataStale();

  /// Check if currently fetching
  bool get isFetching => _isCurrentlyFetching;

  /// Get cache key
  String get key => cacheKey;

  /// Handle window focus event (call this from your app lifecycle)
  void onWindowFocus() {
    if (enableWindowFocusRefresh && _isDataStale() && !_isCurrentlyFetching) {
      _fetchInBackground();
    }
  }

  /// Handle app resume event (call this from your app lifecycle)
  void onAppResume() {
    if (enableBackgroundRefresh && _isDataStale() && !_isCurrentlyFetching) {
      _fetchInBackground();
    }
  }
}

/// Extensions for @riverpod providers to add query capabilities
extension RiverpodQueryExtensions on Ref {
  /// Get the query client for cache operations
  /// 
  /// Example:
  /// ```dart
  /// @riverpod
  /// Future<User> createUser(CreateUserRef ref, Map<String, dynamic> userData) async {
  ///   final queryClient = ref.queryClient;
  ///   
  ///   // Optimistic update
  ///   final currentUsers = queryClient.getQueryData<List<User>>('users');
  ///   if (currentUsers != null) {
  ///     queryClient.setQueryData('users', [...currentUsers, newUser]);
  ///   }
  ///   
  ///   final result = await ApiService.createUser(userData);
  ///   
  ///   // Invalidate cache
  ///   queryClient.invalidateQueries('users');
  ///   
  ///   return result;
  /// }
  /// ```
  QueryClient get queryClient => QueryClient.instance;

  /// Create a smart cached data fetcher with stale-while-revalidate strategy
  /// 
  /// This fetcher implements the following strategy:
  /// 1. If cached data exists, return it immediately
  /// 2. Simultaneously fetch fresh data in background
  /// 3. Update state when fresh data arrives
  /// 4. Support window focus and background refresh
  /// 
  /// Example:
  /// ```dart
  /// @riverpod
  /// class PayrollCheck extends _$PayrollCheck {
  ///   late final _fetcher = ref.cachedFetcher<Result<GetPayrollResponse>>(
  ///     fetchFn: () => ref.read(apiClientProvider).getPayroll(),
  ///     onData: (data) => state = state.copyWith(checkPayrollResult: data, employeesList: data.response?.employees),
  ///     onLoading: () => state = state.copyWith(checkPayrollResult: Result.pending()),
  ///     onError: (error) => state = state.copyWith(checkPayrollResult: Result.fail()),
  ///   );
  /// 
  ///   Future<void> getPayroll() => _fetcher.fetch();
  /// }
  /// ```
  SmartCachedFetcher<T> cachedFetcher<T>({
    required Future<T> Function() fetchFn,
    required void Function(T data) onData,
    required void Function() onLoading,
    required void Function(Object error) onError,
    String? cacheKey,
    Duration staleTime = const Duration(minutes: 5),
    Duration cacheTime = const Duration(minutes: 30),
    bool enableBackgroundRefresh = true,
    bool enableWindowFocusRefresh = true,
    bool cacheErrors = false,
  }) {
    return SmartCachedFetcher<T>(
      ref: this,
      fetchFn: fetchFn,
      onData: onData,
      onLoading: onLoading,
      onError: onError,
      cacheKey: cacheKey,
      staleTime: staleTime,
      cacheTime: cacheTime,
      enableBackgroundRefresh: enableBackgroundRefresh,
      enableWindowFocusRefresh: enableWindowFocusRefresh,
      cacheErrors: cacheErrors,
    );
  }

  /// Invalidate queries by pattern
  /// 
  /// Example:
  /// ```dart
  /// @riverpod
  /// Future<void> deletePost(DeletePostRef ref, int postId) async {
  ///   await ApiService.deletePost(postId);
  ///   ref.invalidateQueries('posts');
  /// }
  /// ```
  void invalidateQueries(String pattern) {
    queryClient.invalidateQueries(pattern);
  }

  /// Set query data optimistically
  /// 
  /// Example:
  /// ```dart
  /// @riverpod
  /// Future<Post> updatePost(UpdatePostRef ref, int postId, Map<String, dynamic> data) async {
  ///   // Optimistic update
  ///   ref.setQueryData('post-$postId', optimisticPost);
  ///   
  ///   try {
  ///     final result = await ApiService.updatePost(postId, data);
  ///     ref.setQueryData('post-$postId', result);
  ///     return result;
  ///   } catch (error) {
  ///     // Rollback on error
  ///     ref.invalidateQueries('post-$postId');
  ///     rethrow;
  ///   }
  /// }
  /// ```
  void setQueryData<T>(String key, T data) {
    queryClient.setQueryData<T>(key, data);
  }

  /// Get cached query data
  /// 
  /// Example:
  /// ```dart
  /// @riverpod
  /// Future<List<Post>> userPosts(UserPostsRef ref, int userId) async {
  ///   // Check if we have cached posts
  ///   final cachedPosts = ref.getQueryData<List<Post>>('posts');
  ///   if (cachedPosts != null) {
  ///     return cachedPosts.where((post) => post.userId == userId).toList();
  ///   }
  ///   
  ///   return ApiService.fetchUserPosts(userId);
  /// }
  /// ```
  T? getQueryData<T>(String key) => queryClient.getQueryData<T>(key);

  /// Remove queries from cache
  /// 
  /// Example:
  /// ```dart
  /// @riverpod
  /// Future<void> logout(LogoutRef ref) async {
  ///   await AuthService.logout();
  ///   ref.removeQueries('user-');  // Remove all user-related queries
  /// }
  /// ```
  void removeQueries(String pattern) {
    queryClient.removeQueries(pattern);
  }
}

/// Mixin to add query capabilities to Notifier or StateNotifier
/// 
/// Example:
/// ```dart
/// class PostsNotifier extends Notifier<List<Post>> with QueryCapabilities<List<Post>> {
///   @override
///   List<Post> build() => [];
/// 
///   Future<void> loadPosts() async {
///     final posts = await executeQuery(
///       queryKey: 'posts',
///       queryFn: () => ApiService.fetchPosts(),
///     );
///     state = posts;
///   }
/// 
///   Future<void> createPost(Map<String, dynamic> postData) async {
///     final newPost = await ApiService.createPost(postData);
///     state = [...state, newPost];
///     invalidateQueries('posts');
///   }
/// }
/// ```
mixin QueryCapabilities<T> on StateNotifier<T> {
  /// Execute a query with caching
  Future<R> executeQuery<R>({
    required String queryKey,
    required Future<R> Function() queryFn,
  }) async {
    final cache = getGlobalQueryCache();
    final cached = cache.get<R>(queryKey);
    
    // Return cached data if available and fresh
    if (cached != null && cached.hasData) {
      return cached.data!;
    }
    
    try {
      final result = await queryFn();
      // Note: Simplified caching - in real implementation you'd want to use proper cache entry creation
      return result;
    } catch (error) {
      rethrow;
    }
  }

  /// Invalidate queries by pattern
  void invalidateQueries(String pattern) {
    final queryClient = QueryClient();
    queryClient.invalidateQueries(pattern);
  }
}

/// Extension for WidgetRef to support hooks integration
extension WidgetRefQueryExtensions on WidgetRef {
  /// Create a smart cached data fetcher with stale-while-revalidate strategy (for hooks)
  SmartCachedFetcher<T> cachedFetcher<T>({
    required Future<T> Function() fetchFn,
    required void Function(T data) onData,
    required void Function() onLoading,
    required void Function(Object error) onError,
    String? cacheKey,
    Duration staleTime = const Duration(minutes: 5),
    Duration cacheTime = const Duration(minutes: 30),
    bool enableBackgroundRefresh = true,
    bool enableWindowFocusRefresh = true,
    bool cacheErrors = false,
  }) {
    return SmartCachedFetcher<T>(
      ref: this,
      fetchFn: fetchFn,
      onData: onData,
      onLoading: onLoading,
      onError: onError,
      cacheKey: cacheKey ?? 'smart-cache-${fetchFn.hashCode}',
      staleTime: staleTime,
      cacheTime: cacheTime,
      enableBackgroundRefresh: enableBackgroundRefresh,
      enableWindowFocusRefresh: enableWindowFocusRefresh,
      cacheErrors: cacheErrors,
    );
  }
  
  /// Get query client for WidgetRef
  QueryClient get queryClient => QueryClient.instance;
  
  /// Invalidate queries by pattern for WidgetRef
  void invalidateQueries(String pattern) {
    QueryClient.instance.invalidateQueries(pattern);
  }
  
  /// Remove queries by pattern for WidgetRef
  void removeQueries(String pattern) {
    QueryClient.instance.removeQueries(pattern);
  }
}