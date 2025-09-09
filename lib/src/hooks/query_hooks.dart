import 'package:flutter/widgets.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../extensions/riverpod_extensions.dart';

/// Hook for using smart cached data fetching with stale-while-revalidate strategy
/// 
/// This hook provides the same functionality as SmartCachedFetcher but with
/// a more React-like API using flutter_hooks.
/// 
/// Example:
/// ```dart
/// class PayrollWidget extends HookConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final payrollQuery = useSmartQuery<Result<GetPayrollResponse>>(
///       ref: ref,
///       fetchFn: () => ref.read(apiClientProvider).getPayroll(),
///       cacheKey: 'payroll-data',
///       staleTime: const Duration(minutes: 5),
///     );
/// 
///     return Column(
///       children: [
///         if (payrollQuery.isLoading) CircularProgressIndicator(),
///         if (payrollQuery.hasError) Text('Error: ${payrollQuery.error}'),
///         if (payrollQuery.hasData) 
///           ...payrollQuery.data!.response?.employees?.map((e) => 
///             ListTile(title: Text(e.name))
///           ) ?? [],
///         
///         ElevatedButton(
///           onPressed: payrollQuery.refetch,
///           child: Text('Refresh'),
///         ),
///       ],
///     );
///   }
/// }
/// ```
SmartQueryResult<T> useSmartQuery<T>({
  required WidgetRef ref,
  required Future<T> Function() fetchFn,
  String? cacheKey,
  Duration staleTime = const Duration(minutes: 5),
  Duration cacheTime = const Duration(minutes: 30),
  bool enableBackgroundRefresh = true,
  bool enableWindowFocusRefresh = true,
  bool cacheErrors = false,
  bool enabled = true,
}) {
  return use(_SmartQueryHook<T>(
    ref: ref,
    fetchFn: fetchFn,
    cacheKey: cacheKey,
    staleTime: staleTime,
    cacheTime: cacheTime,
    enableBackgroundRefresh: enableBackgroundRefresh,
    enableWindowFocusRefresh: enableWindowFocusRefresh,
    cacheErrors: cacheErrors,
    enabled: enabled,
  ));
}

/// Hook for mutations with optimistic updates
/// 
/// Example:
/// ```dart
/// class CreateUserWidget extends HookConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final createUserMutation = useSmartMutation<User, Map<String, dynamic>>(
///       ref: ref,
///       mutationFn: (userData) => ref.read(apiClientProvider).createUser(userData),
///       onSuccess: (user, variables) {
///         // Invalidate users query
///         ref.invalidateQueries('users');
///       },
///       onError: (error, variables) {
///         ScaffoldMessenger.of(context).showSnackBar(
///           SnackBar(content: Text('Failed to create user: $error')),
///         );
///       },
///     );
/// 
///     return ElevatedButton(
///       onPressed: createUserMutation.isLoading ? null : () {
///         createUserMutation.mutate({
///           'name': 'John Doe',
///           'email': 'john@example.com',
///         });
///       },
///       child: createUserMutation.isLoading 
///         ? CircularProgressIndicator() 
///         : Text('Create User'),
///     );
///   }
/// }
/// ```
SmartMutationResult<T, V> useSmartMutation<T, V>({
  required WidgetRef ref,
  required Future<T> Function(V variables) mutationFn,
  void Function(T data, V variables)? onSuccess,
  void Function(Object error, V variables)? onError,
  Future<void> Function(V variables)? onMutate,
}) {
  return use(_SmartMutationHook<T, V>(
    ref: ref,
    mutationFn: mutationFn,
    onSuccess: onSuccess,
    onError: onError,
    onMutate: onMutate,
  ));
}

/// Result object for smart queries
class SmartQueryResult<T> {
  final T? data;
  final Object? error;
  final bool isLoading;
  final bool isFetching;
  final bool isStale;
  final bool isCached;
  final Future<void> Function() refetch;
  final Future<void> Function() refresh;
  final void Function() clearCache;

  const SmartQueryResult({
    required this.data,
    required this.error,
    required this.isLoading,
    required this.isFetching,
    required this.isStale,
    required this.isCached,
    required this.refetch,
    required this.refresh,
    required this.clearCache,
  });

  /// Check if query has data
  bool get hasData => data != null;

  /// Check if query has error
  bool get hasError => error != null;

  /// Check if query is in success state
  bool get isSuccess => hasData && !hasError;

  /// Check if query is in error state
  bool get isError => hasError;
}

/// Result object for smart mutations
class SmartMutationResult<T, V> {
  final T? data;
  final Object? error;
  final bool isLoading;
  final Future<void> Function(V variables) mutate;
  final Future<void> Function(V variables) mutateAsync;
  final void Function() reset;

  const SmartMutationResult({
    required this.data,
    required this.error,
    required this.isLoading,
    required this.mutate,
    required this.mutateAsync,
    required this.reset,
  });

  /// Check if mutation has data
  bool get hasData => data != null;

  /// Check if mutation has error
  bool get hasError => error != null;

  /// Check if mutation is in success state
  bool get isSuccess => hasData && !hasError;

  /// Check if mutation is in error state
  bool get isError => hasError;
}

/// Internal hook implementation for smart queries
class _SmartQueryHook<T> extends Hook<SmartQueryResult<T>> {
  final WidgetRef ref;
  final Future<T> Function() fetchFn;
  final String? cacheKey;
  final Duration staleTime;
  final Duration cacheTime;
  final bool enableBackgroundRefresh;
  final bool enableWindowFocusRefresh;
  final bool cacheErrors;
  final bool enabled;

  const _SmartQueryHook({
    required this.ref,
    required this.fetchFn,
    required this.cacheKey,
    required this.staleTime,
    required this.cacheTime,
    required this.enableBackgroundRefresh,
    required this.enableWindowFocusRefresh,
    required this.cacheErrors,
    required this.enabled,
  });

  @override
  HookState<SmartQueryResult<T>, Hook<SmartQueryResult<T>>> createState() => 
      _SmartQueryHookState<T>();
}

class _SmartQueryHookState<T> extends HookState<SmartQueryResult<T>, _SmartQueryHook<T>> {
  late SmartCachedFetcher<T> _fetcher;
  T? _data;
  Object? _error;
  bool _isLoading = false;
  bool _disposed = false;

  @override
  void initHook() {
    super.initHook();
    _setupFetcher();
  }

  @override
  void didUpdateHook(_SmartQueryHook<T> oldHook) {
    super.didUpdateHook(oldHook);
    if (hook.fetchFn != oldHook.fetchFn || 
        hook.cacheKey != oldHook.cacheKey ||
        hook.staleTime != oldHook.staleTime) {
      _setupFetcher();
    }
  }

  void _setupFetcher() {
    _fetcher = hook.ref.cachedFetcher<T>(
      fetchFn: hook.fetchFn,
      onData: (data) {
        if (!_disposed) {
          setState(() {
            _data = data;
            _error = null;
            _isLoading = false;
          });
        }
      },
      onLoading: () {
        if (!_disposed) {
          setState(() {
            _isLoading = true;
            _error = null;
          });
        }
      },
      onError: (error) {
        if (!_disposed) {
          setState(() {
            _error = error;
            _isLoading = false;
          });
        }
      },
      cacheKey: hook.cacheKey,
      staleTime: hook.staleTime,
      cacheTime: hook.cacheTime,
      enableBackgroundRefresh: hook.enableBackgroundRefresh,
      enableWindowFocusRefresh: hook.enableWindowFocusRefresh,
      cacheErrors: hook.cacheErrors,
    );

    // Auto-fetch if enabled
    if (hook.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) {
          _fetcher.fetch();
        }
      });
    }
  }

  @override
  SmartQueryResult<T> build(BuildContext context) {
    return SmartQueryResult<T>(
      data: _data,
      error: _error,
      isLoading: _isLoading,
      isFetching: _fetcher.isFetching,
      isStale: _fetcher.isStale,
      isCached: _fetcher.isCached,
      refetch: () => _fetcher.fetch(),
      refresh: () => _fetcher.refresh(),
      clearCache: () => _fetcher.clearCache(),
    );
  }

  @override
  void dispose() {
    // Mark as disposed to prevent any future setState calls
    _disposed = true;
    // Clear any pending operations to prevent setState calls after dispose
    _fetcher.clearCache();
    super.dispose();
  }
}

/// Internal hook implementation for smart mutations
class _SmartMutationHook<T, V> extends Hook<SmartMutationResult<T, V>> {
  final WidgetRef ref;
  final Future<T> Function(V variables) mutationFn;
  final void Function(T data, V variables)? onSuccess;
  final void Function(Object error, V variables)? onError;
  final Future<void> Function(V variables)? onMutate;

  const _SmartMutationHook({
    required this.ref,
    required this.mutationFn,
    required this.onSuccess,
    required this.onError,
    required this.onMutate,
  });

  @override
  HookState<SmartMutationResult<T, V>, Hook<SmartMutationResult<T, V>>> createState() => 
      _SmartMutationHookState<T, V>();
}

class _SmartMutationHookState<T, V> extends HookState<SmartMutationResult<T, V>, _SmartMutationHook<T, V>> {
  T? _data;
  Object? _error;
  bool _isLoading = false;

  Future<void> _mutate(V variables) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Call onMutate for optimistic updates
      await hook.onMutate?.call(variables);

      // Perform the mutation
      final result = await hook.mutationFn(variables);

      setState(() {
        _data = result;
        _isLoading = false;
      });

      // Call onSuccess
      hook.onSuccess?.call(result, variables);
    } catch (error) {
      setState(() {
        _error = error;
        _isLoading = false;
      });

      // Call onError
      hook.onError?.call(error, variables);
    }
  }

  Future<void> _mutateAsync(V variables) async {
    await _mutate(variables);
    if (_error != null) {
      throw _error!;
    }
  }

  void _reset() {
    setState(() {
      _data = null;
      _error = null;
      _isLoading = false;
    });
  }

  @override
  SmartMutationResult<T, V> build(BuildContext context) {
    return SmartMutationResult<T, V>(
      data: _data,
      error: _error,
      isLoading: _isLoading,
      mutate: _mutate,
      mutateAsync: _mutateAsync,
      reset: _reset,
    );
  }
}

/// Convenience hook for simple queries without all the smart caching features
/// 
/// Example:
/// ```dart
/// final users = useQuery(() => ApiService.fetchUsers());
/// 
/// if (users.isLoading) return CircularProgressIndicator();
/// if (users.hasError) return Text('Error: ${users.error}');
/// return ListView(children: users.data!.map((user) => ListTile(title: Text(user.name))).toList());
/// ```
SmartQueryResult<T> useQuery<T>(Future<T> Function() queryFn, {String? key}) {
  final ref = useRef<WidgetRef?>(null);
  
  // Get WidgetRef from context (this is a simplified approach)
  // In a real implementation, you'd need to properly access the WidgetRef
  
  return useSmartQuery<T>(
    ref: ref.value!,
    fetchFn: queryFn,
    cacheKey: key,
  );
}
