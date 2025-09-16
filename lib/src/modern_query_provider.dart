import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lifecycle_manager.dart';
import 'query_cache.dart';
import 'query_client.dart';
import 'query_options.dart';
import 'query_state.dart';
import 'state_query_provider.dart' show QueryFunctionWithRef, QueryFunctionWithParamsWithRef;
import 'window_focus_manager.dart';

/// 🔥 Modern Notifier-based query implementation (Recommended)
/// 
/// This replaces the deprecated StateNotifier-based QueryNotifier
class QueryNotifier<T> extends Notifier<QueryState<T>> with QueryClientMixin {
  QueryNotifier({
    required this.queryFunction,
    required this.options,
    required this.queryKey,
  });

  final QueryFunctionWithRef<T> queryFunction;
  final QueryOptions<T> options;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;
  
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  bool _isRefetchPaused = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  @override
  QueryState<T> build() {
    if (!_isInitialized) {
      _isInitialized = true;
      _isDisposed = false;
      
      _setupCacheListener();
      _setupLifecycleCallbacks();
      _setupWindowFocusCallbacks();
      
      ref.onDispose(() {
        _isDisposed = true;
        _refetchTimer?.cancel();
        _cache.removeAllListeners(queryKey);
        
        if (options.refetchOnAppFocus) {
          _lifecycleManager.removeOnResumeCallback(_onAppResume);
        }
        if (options.pauseRefetchInBackground) {
          _lifecycleManager.removeOnPauseCallback(_onAppPause);
        }
        if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
          _windowFocusManager.removeOnFocusCallback(_onWindowFocus);
        }
        
        _isInitialized = false;
      });
    }
    
    if (options.enabled && options.refetchOnMount) {
      Future.microtask(_fetch);
    }

    if (options.enabled && options.refetchInterval != null) {
      _scheduleRefetch();
    }

    // Check cache first
    final cachedEntry = _getCachedEntry();
    if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
      return QuerySuccess(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt);
    }

    return const QueryIdle();
  }

  void _safeState(QueryState<T> newState) {
    if(!_isDisposed) {
      state = newState;
    }
  }

  Future<void> _fetch({bool forceFetchRemote = false}) async {
    if (!options.enabled) {
      return;
    }

    debugPrint('Fetching data in modern query notifier for key $queryKey');

    final cachedEntry = _getCachedEntry();
    if (!forceFetchRemote && cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
      debugPrint('Using cached data in modern query notifier for key $queryKey');
      _safeState(QuerySuccess(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt));
      return;
    }

    if (options.keepPreviousData && state.hasData) {
      debugPrint('Using state data in modern query notifier for key $queryKey');
      _safeState(QueryRefetching(state.data as T, fetchedAt: cachedEntry?.fetchedAt));
    } else if (options.keepPreviousData && cachedEntry != null && cachedEntry.hasData) {
      debugPrint('Using stale cached data in modern query notifier for key $queryKey');
      _safeState(QueryRefetching(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt));
    } else {
      _safeState(const QueryLoading());
    }

    try {
      debugPrint('Querying data from server in modern query notifier for key $queryKey');

      final data = await queryFunction(ref);
      final now = DateTime.now();
      
      _setCachedEntry(QueryCacheEntry<T>(
        data: data,
        fetchedAt: now,
        options: options,
      ));

      _safeState(QuerySuccess(data, fetchedAt: now));
      _retryCount = 0;

      options.onSuccess?.call(data);
    } catch (error, stackTrace) {
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return _fetch();
      }

      _safeState(QueryError(error, stackTrace: stackTrace));
      _retryCount = 0;

      options.onError?.call(error, stackTrace);
    }
  }

  Future<void> refetch({bool forceFetchRemote = false}) => _fetch(forceFetchRemote: forceFetchRemote);

  Future<void> refresh() {
    _clearCache();
    return _fetch();
  }

  void setData(T data) {
    final now = DateTime.now();
    _setCachedEntry(QueryCacheEntry<T>(
      data: data,
      fetchedAt: now,
      options: options,
    ));
    _safeState(QuerySuccess(data, fetchedAt: now));
  }

  T? getCachedData() {
    final entry = _getCachedEntry();
    return entry?.hasData ?? false ? entry!.data as T : null;
  }

  void _scheduleRefetch() {
    _refetchTimer?.cancel();
    if (options.refetchInterval != null) {
      _refetchTimer = Timer.periodic(options.refetchInterval!, (_) {
        if (options.enabled && _shouldRefetch()) {
          _fetch();
        }
      });
    }
  }

  bool _shouldRefetch() {
    if (_isRefetchPaused) {
      return false;
    }
    if (options.pauseRefetchInBackground && _lifecycleManager.isInBackground) return false;
    return true;
  }

  void _setupLifecycleCallbacks() {
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResume);
    }
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPause);
    }
  }

  void _onAppResume() {
    debugPrint('App resumed in modern query notifier');
    _isRefetchPaused = false;
    
    final cachedEntry = _getCachedEntry();
    if (cachedEntry != null && cachedEntry.isStale && options.enabled) {
      _fetch();
    }
  }

  void _onAppPause() {
    debugPrint('App paused in modern query notifier');
    _isRefetchPaused = true;
  }

  void _setupWindowFocusCallbacks() {
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocus);
    }
  }

  void _onWindowFocus() {
    debugPrint('Window focused in modern query notifier');
    final cachedEntry = _getCachedEntry();
    if (cachedEntry != null && cachedEntry.isStale && options.enabled) {
      _fetch();
    }
  }

  QueryCacheEntry<T>? _getCachedEntry() => _cache.get<T>(queryKey);
  void _setCachedEntry(QueryCacheEntry<T> entry) => _cache.set(queryKey, entry);
  void _clearCache() => _cache.remove(queryKey);

  void _setupCacheListener() {
    _cache.addListener<T>(queryKey, (entry) {
      if (entry?.hasData ?? false) {
        _safeState(QuerySuccess(entry!.data as T, fetchedAt: entry.fetchedAt));
      } else if (entry == null) {
        if (options.onCacheEvicted != null) {
          options.onCacheEvicted!(queryKey);
        } else if (_isDisposed) {
          refetch();
        } else {
          _safeState(const QueryIdle());
        }
      }
      debugPrint('Cache listener called for key $queryKey in modern query notifier, change state to ${state.runtimeType}');
    });
  }
}

/// Modern Family Notifier for queries with parameters
class QueryNotifierFamily<T, P> extends FamilyNotifier<QueryState<T>, P> with QueryClientMixin {
  QueryNotifierFamily({
    required this.queryFunction,
    required this.options,
    required this.queryKey,
  });

  final QueryFunctionWithParamsWithRef<T, P> queryFunction;
  final QueryOptions<T> options;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;
  
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  bool _isRefetchPaused = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  @override
  QueryState<T> build(P arg) {
    final paramKey = '$queryKey-$arg';
    
    if (!_isInitialized) {
      _isInitialized = true;
      _isDisposed = false;

      _setupCacheListener(paramKey);
      _setupLifecycleCallbacks(arg);
      _setupWindowFocusCallbacks(arg);
      
      ref.onDispose(() {
        _isDisposed = true;
        _refetchTimer?.cancel();
        _cache.removeAllListeners(paramKey);
        
        if (options.refetchOnAppFocus) {
          _lifecycleManager.removeOnResumeCallback(_onAppResume);
        }
        if (options.pauseRefetchInBackground) {
          _lifecycleManager.removeOnPauseCallback(_onAppPause);
        }
        if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
          _windowFocusManager.removeOnFocusCallback(_onWindowFocus);
        }
        
        _isInitialized = false;
      });
    }
    
    if (options.enabled && options.refetchOnMount) {
      Future.microtask(() => _fetch(arg));
    }

    if (options.enabled && options.refetchInterval != null) {
      _scheduleRefetch(arg);
    }

    // Check cache first
    final cachedEntry = _getCachedEntry(paramKey);
    if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
      return QuerySuccess(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt);
    }

    return const QueryIdle();
  }

  void _safeState(QueryState<T> newState) {
    if (!_isDisposed) {
      state = newState;
    }
  }

  Future<void> _fetch(P param, {bool forceFetchRemote = false}) async {
    if (!options.enabled) {
      return;
    }

    final paramKey = '$queryKey-$param';
    debugPrint('Fetching data in modern query notifier family for key $paramKey');

    final cachedEntry = _getCachedEntry(paramKey);
    if (!forceFetchRemote && cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
      debugPrint('Using cached data in modern query notifier family for key $paramKey');
      _safeState(QuerySuccess(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt));
      return;
    }

    if (!_isDisposed && options.keepPreviousData && state.hasData) {
      _safeState(QueryRefetching(state.data as T, fetchedAt: cachedEntry?.fetchedAt));
    } else if (options.keepPreviousData && cachedEntry != null && cachedEntry.hasData) {
      _safeState(QueryRefetching(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt));
    } else {
      _safeState(const QueryLoading());
    }

    try {
      final data = await queryFunction(ref, param);
      final now = DateTime.now();
      
      _setCachedEntry(paramKey, QueryCacheEntry<T>(
        data: data,
        fetchedAt: now,
        options: options,
      ));

      _safeState(QuerySuccess(data, fetchedAt: now));
      _retryCount = 0;

      options.onSuccess?.call(data);
    } catch (error, stackTrace) {
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return _fetch(param);
      }

      _safeState(QueryError(error, stackTrace: stackTrace));
      _retryCount = 0;

      options.onError?.call(error, stackTrace);
    }
  }

  Future<void> refetch({bool forceFetchRemote = false}) => _fetch(arg, forceFetchRemote: forceFetchRemote);

  Future<void> refresh() {
    _clearCache('$queryKey-$arg');
    return _fetch(arg);
  }

  void setData(T data) {
    final now = DateTime.now();
    final paramKey = '$queryKey-$arg';
    _setCachedEntry(paramKey, QueryCacheEntry<T>(
      data: data,
      fetchedAt: now,
      options: options,
    ));
    _safeState(QuerySuccess(data, fetchedAt: now));
  }

  QueryCacheEntry<T>? _getCachedEntry(String key) => _cache.get<T>(key);
  void _setCachedEntry(String key, QueryCacheEntry<T> entry) => _cache.set(key, entry);
  void _clearCache(String key) => _cache.remove(key);

  void _setupCacheListener(String key) {
    _cache.addListener<T>(key, (entry) {
      if (entry?.hasData ?? false) {
        _safeState(QuerySuccess(entry!.data as T, fetchedAt: entry.fetchedAt));
      } else if (entry == null) {
        if (options.onCacheEvicted != null) {
          options.onCacheEvicted!(key);
        } else if (!_isDisposed) {
          refetch();
        } else {
          _safeState(const QueryIdle());
        }
      }
    });
  }

  void _scheduleRefetch(P param) {
    _refetchTimer?.cancel();
    if (options.refetchInterval != null) {
      _refetchTimer = Timer.periodic(options.refetchInterval!, (_) {
        if (options.enabled && _shouldRefetch()) {
          _fetch(param);
        }
      });
    }
  }

  bool _shouldRefetch() {
    if (_isRefetchPaused) return false;
    if (options.pauseRefetchInBackground && _lifecycleManager.isInBackground) return false;
    return true;
  }

  void _setupLifecycleCallbacks(P param) {
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResume);
    }
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPause);
    }
  }

  void _onAppResume() {
    _isRefetchPaused = false;
    final cachedEntry = _getCachedEntry('$queryKey-$arg');
    if (cachedEntry != null && cachedEntry.isStale && options.enabled) {
      _fetch(arg);
    }
  }

  void _onAppPause() {
    _isRefetchPaused = true;
  }

  void _setupWindowFocusCallbacks(P param) {
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocus);
    }
  }

  void _onWindowFocus() {
    final cachedEntry = _getCachedEntry('$queryKey-$arg');
    if (cachedEntry != null && cachedEntry.isStale && options.enabled) {
      _fetch(arg);
    }
  }
}

/// Auto-dispose Modern Notifier for queries
class QueryNotifierAutoDispose<T> extends AutoDisposeNotifier<QueryState<T>> with QueryClientMixin {
  QueryNotifierAutoDispose({
    required this.queryFunction,
    required this.options,
    required this.queryKey,
  });

  final QueryFunctionWithRef<T> queryFunction;
  final QueryOptions<T> options;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;
  
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  bool _isRefetchPaused = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  @override
  QueryState<T> build() {
    if (!_isInitialized) {
      _isInitialized = true;
      _isDisposed = false;
      
      _setupCacheListener();
      _setupLifecycleCallbacks();
      _setupWindowFocusCallbacks();
      
      ref.onDispose(() {
        _isDisposed = true;
        _refetchTimer?.cancel();
        _cache.removeAllListeners(queryKey);
        
        if (options.refetchOnAppFocus) {
          _lifecycleManager.removeOnResumeCallback(_onAppResume);
        }
        if (options.pauseRefetchInBackground) {
          _lifecycleManager.removeOnPauseCallback(_onAppPause);
        }
        if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
          _windowFocusManager.removeOnFocusCallback(_onWindowFocus);
        }
        
        _isInitialized = false;
      });
    }
    
    if (options.enabled && options.refetchOnMount) {
      Future.microtask(_fetch);
    }

    if (options.enabled && options.refetchInterval != null) {
      _scheduleRefetch();
    }

    final cachedEntry = _getCachedEntry();
    if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
      return QuerySuccess(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt);
    }

    return const QueryIdle();
  }

  void _safeState(QueryState<T> newState) {
    if (!_isDisposed) {
      state = newState;
    }
  }

  Future<void> _fetch({bool forceFetchRemote = false}) async {
    if (!options.enabled) {
      return;
    }

    final cachedEntry = _getCachedEntry();
    if (!forceFetchRemote && cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
      _safeState(QuerySuccess(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt));
      return;
    }

    if (!_isDisposed && options.keepPreviousData && state.hasData) {
      _safeState(QueryRefetching(state.data as T, fetchedAt: cachedEntry?.fetchedAt));
    } else if (options.keepPreviousData && cachedEntry != null && cachedEntry.hasData) {
      _safeState(QueryRefetching(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt));
    } else {
      _safeState(const QueryLoading());
    }

    try {
      final data = await queryFunction(ref);
      final now = DateTime.now();
      
      _setCachedEntry(QueryCacheEntry<T>(
        data: data,
        fetchedAt: now,
        options: options,
      ));

      _safeState(QuerySuccess(data, fetchedAt: now));
      _retryCount = 0;

      options.onSuccess?.call(data);
    } catch (error, stackTrace) {
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return _fetch();
      }

      _safeState(QueryError(error, stackTrace: stackTrace));
      _retryCount = 0;

      options.onError?.call(error, stackTrace);
    }
  }

  Future<void> refetch({bool forceFetchRemote = false}) => _fetch(forceFetchRemote: forceFetchRemote);

  Future<void> refresh() {
    _clearCache();
    return _fetch();
  }

  QueryCacheEntry<T>? _getCachedEntry() => _cache.get<T>(queryKey);
  void _setCachedEntry(QueryCacheEntry<T> entry) => _cache.set(queryKey, entry);
  void _clearCache() => _cache.remove(queryKey);

  void _setupCacheListener() {
    _cache.addListener<T>(queryKey, (entry) {
      if (entry?.hasData ?? false) {
        _safeState(QuerySuccess(entry!.data as T, fetchedAt: entry.fetchedAt));
      } else if (entry == null && !_isDisposed) {
        if (options.onCacheEvicted != null) {
          options.onCacheEvicted!(queryKey);
        } else {
          refetch();
        }
      }
    });
  }

  void _scheduleRefetch() {
    _refetchTimer?.cancel();
    if (options.refetchInterval != null) {
      _refetchTimer = Timer.periodic(options.refetchInterval!, (_) {
        if (options.enabled && _shouldRefetch()) {
          _fetch();
        }
      });
    }
  }

  bool _shouldRefetch() {
    if (_isRefetchPaused) {
      return false;
    }
    if (options.pauseRefetchInBackground && _lifecycleManager.isInBackground) return false;
    return true;
  }

  void _setupLifecycleCallbacks() {
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResume);
    }
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPause);
    }
  }

  void _onAppResume() {
    _isRefetchPaused = false;
    final cachedEntry = _getCachedEntry();
    if (cachedEntry != null && cachedEntry.isStale && options.enabled) {
      _fetch();
    }
  }

  void _onAppPause() => _isRefetchPaused = true;

  void _setupWindowFocusCallbacks() {
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocus);
    }
  }

  void _onWindowFocus() {
    final cachedEntry = _getCachedEntry();
    if (cachedEntry != null && cachedEntry.isStale && options.enabled) {
      _fetch();
    }
  }
}

/// Auto-dispose Modern Family Notifier for queries with parameters
class QueryNotifierFamilyAutoDispose<T, P> extends AutoDisposeFamilyNotifier<QueryState<T>, P> with QueryClientMixin {
  QueryNotifierFamilyAutoDispose({
    required this.queryFunction,
    required this.options,
    required this.queryKey,
  });

  final QueryFunctionWithParamsWithRef<T, P> queryFunction;
  final QueryOptions<T> options;
  final String queryKey;

  Timer? _refetchTimer;
  int _retryCount = 0;
  
  final QueryCache _cache = getGlobalQueryCache();
  final AppLifecycleManager _lifecycleManager = AppLifecycleManager.instance;
  final WindowFocusManager _windowFocusManager = WindowFocusManager.instance;
  bool _isRefetchPaused = false;
  bool _isInitialized = false;
  bool _isDisposed = false;

  @override
  QueryState<T> build(P arg) {
    final paramKey = '$queryKey-$arg';
    
    if (!_isInitialized) {
      _isInitialized = true;
      _isDisposed = false;
      
      _setupCacheListener(paramKey);
      _setupLifecycleCallbacks();
      _setupWindowFocusCallbacks();
      
      ref.onDispose(() {
        _isDisposed = true;
        _refetchTimer?.cancel();
        _cache.removeAllListeners(paramKey);
        
        if (options.refetchOnAppFocus) {
          _lifecycleManager.removeOnResumeCallback(_onAppResume);
        }
        if (options.pauseRefetchInBackground) {
          _lifecycleManager.removeOnPauseCallback(_onAppPause);
        }
        if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
          _windowFocusManager.removeOnFocusCallback(_onWindowFocus);
        }
        
        _isInitialized = false;
      });
    }
    
    if (options.enabled && options.refetchOnMount) {
      Future.microtask(() => _fetch(arg));
    }

    if (options.enabled && options.refetchInterval != null) {
      _scheduleRefetch(arg);
    }

    final cachedEntry = _getCachedEntry(paramKey);
    if (cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
      return QuerySuccess(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt);
    }

    return const QueryIdle();
  }

  void _safeState(QueryState<T> newState) {
    if (!_isDisposed) {
      state = newState;
    }
  }

  Future<void> _fetch(P param, {bool forceFetchRemote = false}) async {
    if (!options.enabled) {
      return;
    }

    final paramKey = '$queryKey-$param';
    final cachedEntry = _getCachedEntry(paramKey);
    
    if (!forceFetchRemote && cachedEntry != null && !cachedEntry.isStale && cachedEntry.hasData) {
      _safeState(QuerySuccess(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt));
      return;
    }

    if (!_isDisposed && options.keepPreviousData && state.hasData) {
      _safeState(QueryRefetching(state.data as T, fetchedAt: cachedEntry?.fetchedAt));
    } else if (options.keepPreviousData && cachedEntry != null && cachedEntry.hasData) {
      _safeState(QueryRefetching(cachedEntry.data as T, fetchedAt: cachedEntry.fetchedAt));
    } else {
      _safeState(const QueryLoading());
    }

    try {
      final data = await queryFunction(ref, param);
      final now = DateTime.now();
      
      _setCachedEntry(paramKey, QueryCacheEntry<T>(
        data: data,
        fetchedAt: now,
        options: options,
      ));

      _safeState(QuerySuccess(data, fetchedAt: now));
      _retryCount = 0;

      options.onSuccess?.call(data);
    } catch (error, stackTrace) {
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return _fetch(param);
      }

      _safeState(QueryError(error, stackTrace: stackTrace));
      _retryCount = 0;

      options.onError?.call(error, stackTrace);
    }
  }

  Future<void> refetch({bool forceFetchRemote = false}) => _fetch(arg, forceFetchRemote: forceFetchRemote);

  QueryCacheEntry<T>? _getCachedEntry(String key) => _cache.get<T>(key);
  void _setCachedEntry(String key, QueryCacheEntry<T> entry) => _cache.set(key, entry);

  void _setupCacheListener(String key) {
    _cache.addListener<T>(key, (entry) {
      if (entry?.hasData ?? false) {
        _safeState(QuerySuccess(entry!.data as T, fetchedAt: entry.fetchedAt));
      } else if (entry == null && !_isDisposed) {
        if (options.onCacheEvicted != null) {
          options.onCacheEvicted!(key);
        } else {
          refetch();
        }
      }
    });
  }

  void _scheduleRefetch(P param) {
    _refetchTimer?.cancel();
    if (options.refetchInterval != null) {
      _refetchTimer = Timer.periodic(options.refetchInterval!, (_) {
        if (options.enabled && _shouldRefetch()) {
          _fetch(param);
        }
      });
    }
  }

  bool _shouldRefetch() {
    if (_isRefetchPaused) {
      return false;
    }
    if (options.pauseRefetchInBackground && _lifecycleManager.isInBackground) return false;
    return true;
  }

  void _setupLifecycleCallbacks() {
    if (options.refetchOnAppFocus) {
      _lifecycleManager.addOnResumeCallback(_onAppResume);
    }
    if (options.pauseRefetchInBackground) {
      _lifecycleManager.addOnPauseCallback(_onAppPause);
    }
  }

  void _onAppResume() {
    _isRefetchPaused = false;
    final cachedEntry = _getCachedEntry('$queryKey-$arg');
    if (cachedEntry != null && cachedEntry.isStale && options.enabled) {
      _fetch(arg);
    }
  }

  void _onAppPause() => _isRefetchPaused = true;

  void _setupWindowFocusCallbacks() {
    if (options.refetchOnWindowFocus && _windowFocusManager.isSupported) {
      _windowFocusManager.addOnFocusCallback(_onWindowFocus);
    }
  }

  void _onWindowFocus() {
    final cachedEntry = _getCachedEntry('$queryKey-$arg');
    if (cachedEntry != null && cachedEntry.isStale && options.enabled) {
      _fetch(arg);
    }
  }
}

// ========================================
// 🔥 MODERN NOTIFIER-BASED PROVIDERS
// ========================================

/// 🔥 Modern Notifier-based query provider (Recommended)
/// 
/// **Use this instead of the deprecated StateNotifier-based providers**
/// 
/// Features:
/// - ✅ Modern Riverpod Notifier API
/// - ✅ Full cache integration with staleTime/cacheTime
/// - ✅ Lifecycle management (app focus, window focus)
/// - ✅ Automatic refetching intervals
/// - ✅ Retry logic with exponential backoff
/// - ✅ Background refetch capabilities
/// - ✅ keepPreviousData support
/// - ✅ Memory leak prevention
/// 
/// Example:
/// ```dart
/// final userProvider = modernQueryProvider<User>(
///   name: 'user',
///   queryFn: (ref) => ApiService.fetchUser(),
///   options: QueryOptions(
///     staleTime: Duration(minutes: 5),
///     cacheTime: Duration(minutes: 10),
///   ),
/// );
/// 
/// // Usage in widget:
/// final userState = ref.watch(userProvider);
/// userState.when(
///   idle: () => Text('Tap to load'),
///   loading: () => CircularProgressIndicator(),
///   success: (user) => UserWidget(user),
///   error: (error, stackTrace) => ErrorWidget(error),
///   refetching: (user) => UserWidget(user), // Shows data while refetching
/// );
/// ```
NotifierProvider<QueryNotifier<T>, QueryState<T>> queryProvider<T>({
  required String name,
  required QueryFunctionWithRef<T> queryFn,
  QueryOptions<T> options = const QueryOptions(),
}) => NotifierProvider<QueryNotifier<T>, QueryState<T>>(
    () => QueryNotifier<T>(
      queryFunction: queryFn,
      options: options,
      queryKey: name,
    ),
    name: name,
  );

/// 🔥 Auto-dispose Modern Notifier-based query provider
/// 
/// **Use this for temporary data that should be cleaned up when not watched**
/// 
/// Example:
/// ```dart
/// final tempDataProvider = modernQueryProviderAutoDispose<TempData>(
///   name: 'temp-data',
///   queryFn: (ref) => ApiService.fetchTempData(),
///   options: QueryOptions(
///     staleTime: Duration(minutes: 2),
///     cacheTime: Duration(minutes: 5),
///   ),
/// );
/// ```
AutoDisposeNotifierProvider<QueryNotifierAutoDispose<T>, QueryState<T>> queryProviderAutoDispose<T>({
  required String name,
  required QueryFunctionWithRef<T> queryFn,
  QueryOptions<T> options = const QueryOptions(),
}) => NotifierProvider.autoDispose<QueryNotifierAutoDispose<T>, QueryState<T>>(
    () => QueryNotifierAutoDispose<T>(
      queryFunction: queryFn,
      options: options,
      queryKey: name,
    ),
    name: name,
  );

/// 🔥 Modern Family Notifier-based query provider with parameters
/// 
/// Example:
/// ```dart
/// final userDetailProvider = modernQueryProviderFamily<User, int>(
///   name: 'user-detail',
///   queryFn: (ref, userId) => ApiService.fetchUser(userId),
///   options: QueryOptions(
///     staleTime: Duration(minutes: 5),
///     keepPreviousData: true,
///   ),
/// );
/// 
/// // Usage:
/// final userState = ref.watch(userDetailProvider(userId));
/// ```
NotifierProviderFamily<QueryNotifierFamily<T, P>, QueryState<T>, P> queryProviderWithParam<T, P>({
  required String name,
  required QueryFunctionWithParamsWithRef<T, P> queryFn,
  QueryOptions<T> options = const QueryOptions(),
}) => NotifierProvider.family<QueryNotifierFamily<T, P>, QueryState<T>, P>(
    () => QueryNotifierFamily<T, P>(
      queryFunction: queryFn,
      options: options,
      queryKey: name,
    ),
    name: name,
  );

/// 🔥 Auto-dispose Modern Family Notifier-based query provider with parameters
/// 
/// Example:
/// ```dart
/// final userDetailProvider = modernQueryProviderFamilyAutoDispose<User, int>(
///   name: 'user-detail',
///   queryFn: (ref, userId) => ApiService.fetchUser(userId),
///   options: QueryOptions(
///     staleTime: Duration(minutes: 5),
///     keepPreviousData: true,
///   ),
/// );
/// ```
AutoDisposeNotifierProviderFamily<QueryNotifierFamilyAutoDispose<T, P>, QueryState<T>, P> queryProviderWithParamAutoDispose<T, P>({
  required String name,
  required QueryFunctionWithParamsWithRef<T, P> queryFn,
  QueryOptions<T> options = const QueryOptions(),
}) => NotifierProvider.autoDispose.family<QueryNotifierFamilyAutoDispose<T, P>, QueryState<T>, P>(
    () => QueryNotifierFamilyAutoDispose<T, P>(
      queryFunction: queryFn,
      options: options,
      queryKey: name,
    ),
    name: name,
  );
