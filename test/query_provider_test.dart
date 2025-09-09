import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:query_provider/query_provider.dart';

// Mock data and functions for testing
class MockApiService {
  static int callCount = 0;
  static bool shouldFail = false;
  static Duration delay = const Duration(milliseconds: 100);
  
  static Future<String> fetchData() async {
    await Future.delayed(delay);
    callCount++;
    
    if (shouldFail) {
      throw Exception('Mock API error');
    }
    
    return 'Mock data $callCount';
  }
  
  static Future<String> fetchDataWithParam(String param) async {
    await Future.delayed(delay);
    callCount++;
    
    if (shouldFail) {
      throw Exception('Mock API error with param: $param');
    }
    
    return 'Mock data for $param - $callCount';
  }
  
  static void reset() {
    callCount = 0;
    shouldFail = false;
    delay = const Duration(milliseconds: 100);
  }
}

void main() {
  group('QueryNotifier', () {
    late ProviderContainer container;
    
    setUp(() {
      MockApiService.reset();
      container = ProviderContainer();
      // Clear global cache
      getGlobalQueryCache().clear();
    });
    
    tearDown(() {
      container.dispose();
    });

    test('should start in idle state', () {
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
      );
      
      final state = container.read(provider);
      expect(state, isA<QueryIdle<String>>());
      expect(state.isIdle, true);
      expect(state.hasData, false);
    });

    test('should fetch data on mount when refetchOnMount is true', () async {
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: const QueryOptions(refetchOnMount: true),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait for async operation
      await Future.delayed(const Duration(milliseconds: 150));
      
      final state = container.read(provider);
      expect(state, isA<QuerySuccess<String>>());
      expect((state as QuerySuccess<String>).data, 'Mock data 1');
      expect(MockApiService.callCount, 1);
    });

    test('should not fetch data on mount when refetchOnMount is false', () async {
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: const QueryOptions(refetchOnMount: false),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 150));
      
      final state = container.read(provider);
      expect(state, isA<QueryIdle<String>>());
      expect(MockApiService.callCount, 0);
    });

    test('should handle loading state correctly', () async {
      MockApiService.delay = const Duration(milliseconds: 200);
      
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: const QueryOptions(refetchOnMount: true),
      );
      
      final states = <QueryState<String>>[];
      container.listen(provider, (previous, next) {
        states.add(next);
      });
      
      // Wait for loading state
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(states.isNotEmpty, true);
      expect(states.first, isA<QueryLoading<String>>());
      
      // Wait for completion
      await Future.delayed(const Duration(milliseconds: 200));
      
      expect(states.last, isA<QuerySuccess<String>>());
    });

    test('should handle error state correctly', () async {
      MockApiService.shouldFail = true;
      
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: const QueryOptions(refetchOnMount: true),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait for async operation
      await Future.delayed(const Duration(milliseconds: 150));
      
      final state = container.read(provider);
      expect(state, isA<QueryError<String>>());
      expect((state as QueryError<String>).error.toString(), contains('Mock API error'));
    });

    test('should retry on failure', () async {
      MockApiService.shouldFail = true;
      
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: const QueryOptions(
          refetchOnMount: true,
          retry: 2,
          retryDelay: Duration(milliseconds: 50),
        ),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait for retries to complete
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Should have called 3 times (initial + 2 retries)
      expect(MockApiService.callCount, 3);
      
      final state = container.read(provider);
      expect(state, isA<QueryError<String>>());
    });

    test('should succeed after retry', () async {
      var failCount = 0;
      
      Future<String> flakyFetch() async {
        await Future.delayed(const Duration(milliseconds: 50));
        failCount++;
        
        if (failCount <= 2) {
          throw Exception('Temporary failure');
        }
        
        return 'Success after retries';
      }
      
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: flakyFetch,
        options: const QueryOptions(
          refetchOnMount: true,
          retry: 3,
          retryDelay: Duration(milliseconds: 10),
        ),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait for retries to complete
      await Future.delayed(const Duration(milliseconds: 200));
      
      final state = container.read(provider);
      expect(state, isA<QuerySuccess<String>>());
      expect((state as QuerySuccess<String>).data, 'Success after retries');
      expect(failCount, 3);
    });

    test('should refetch manually', () async {
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: const QueryOptions(refetchOnMount: true),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait for initial fetch
      await Future.delayed(const Duration(milliseconds: 150));
      
      expect(MockApiService.callCount, 1);
      
      // Manual refetch
      await container.read(provider.notifier).refetch();
      
      expect(MockApiService.callCount, 2);
      
      final state = container.read(provider);
      expect(state, isA<QuerySuccess<String>>());
      expect((state as QuerySuccess<String>).data, 'Mock data 2');
    });

    test('should invalidate and refetch', () async {
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: const QueryOptions(refetchOnMount: true),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait for initial fetch
      await Future.delayed(const Duration(milliseconds: 150));
      
      expect(MockApiService.callCount, 1);
      
      // Check cache has data
      final cache = getGlobalQueryCache();
      expect(cache.get<String>('test-query'), isNotNull);
      
      // Invalidate
      await container.read(provider.notifier).invalidate();
      
      expect(MockApiService.callCount, 2);
      
      final state = container.read(provider);
      expect(state, isA<QuerySuccess<String>>());
    });

    test('should set data manually', () async {
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: const QueryOptions(refetchOnMount: false),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Set data manually
      container.read(provider.notifier).setData('Manual data');
      
      final state = container.read(provider);
      expect(state, isA<QuerySuccess<String>>());
      expect((state as QuerySuccess<String>).data, 'Manual data');
      expect(MockApiService.callCount, 0); // No API call
    });

    test('should get cached data', () async {
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: const QueryOptions(refetchOnMount: true),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait for initial fetch
      await Future.delayed(const Duration(milliseconds: 150));
      
      final cachedData = container.read(provider.notifier).getCachedData();
      expect(cachedData, 'Mock data 1');
    });

    test('should handle disabled query', () async {
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: const QueryOptions(
          refetchOnMount: true,
          enabled: false,
        ),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait a bit
      await Future.delayed(const Duration(milliseconds: 150));
      
      final state = container.read(provider);
      expect(state, isA<QueryIdle<String>>());
      expect(MockApiService.callCount, 0);
    });

    test('should use cached data when available and fresh', () async {
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: const QueryOptions(
          refetchOnMount: true,
          staleTime: Duration(minutes: 5),
        ),
      );
      
      // First fetch
      container.listen(provider, (previous, next) {});
      await Future.delayed(const Duration(milliseconds: 150));
      
      expect(MockApiService.callCount, 1);
      
      // Create new container (simulating app restart)
      container.dispose();
      container = ProviderContainer();
      
      // Second fetch should use cache
      container.listen(provider, (previous, next) {});
      await Future.delayed(const Duration(milliseconds: 50));
      
      final state = container.read(provider);
      expect(state, isA<QuerySuccess<String>>());
      expect((state as QuerySuccess<String>).data, 'Mock data 1');
      expect(MockApiService.callCount, 1); // No additional call
    });

    test('should show refetching state with keepPreviousData', () async {
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: const QueryOptions(
          refetchOnMount: true,
          keepPreviousData: true,
          staleTime: Duration.zero, // Always stale
        ),
      );
      
      final states = <QueryState<String>>[];
      container.listen(provider, (previous, next) {
        states.add(next);
      });
      
      // Wait for initial fetch
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Trigger refetch
      await container.read(provider.notifier).refetch();
      
      // Should have refetching state
      final refetchingStates = states.whereType<QueryRefetching<String>>();
      expect(refetchingStates.isNotEmpty, true);
      
      final refetchingState = refetchingStates.first;
      expect(refetchingState.previousData, 'Mock data 1');
    });

    test('should call success callback', () async {
      String? successData;
      
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: QueryOptions(
          refetchOnMount: true,
          onSuccess: (data) {
            successData = data;
          },
        ),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait for fetch
      await Future.delayed(const Duration(milliseconds: 150));
      
      expect(successData, 'Mock data 1');
    });

    test('should call error callback', () async {
      Object? errorReceived;
      StackTrace? stackTraceReceived;
      
      MockApiService.shouldFail = true;
      
      final provider = queryProvider<String>(
        name: 'test-query',
        queryFn: MockApiService.fetchData,
        options: QueryOptions(
          refetchOnMount: true,
          retry: 0, // No retries
          onError: (error, stackTrace) {
            errorReceived = error;
            stackTraceReceived = stackTrace;
          },
        ),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait for fetch
      await Future.delayed(const Duration(milliseconds: 150));
      
      expect(errorReceived, isNotNull);
      expect(errorReceived.toString(), contains('Mock API error'));
      expect(stackTraceReceived, isNotNull);
    });
  });

  group('queryProviderFamily', () {
    late ProviderContainer container;
    
    setUp(() {
      MockApiService.reset();
      container = ProviderContainer();
      getGlobalQueryCache().clear();
    });
    
    tearDown(() {
      container.dispose();
    });

    test('should create different instances for different parameters', () async {
      final provider = queryProviderFamily<String, String>(
        name: 'user-query',
        queryFn: MockApiService.fetchDataWithParam,
        options: const QueryOptions(refetchOnMount: true),
      );
      
      // Listen to different parameters
      container.listen(provider('user1'), (previous, next) {});
      container.listen(provider('user2'), (previous, next) {});
      
      // Wait for fetches
      await Future.delayed(const Duration(milliseconds: 150));
      
      final state1 = container.read(provider('user1'));
      final state2 = container.read(provider('user2'));
      
      expect(state1, isA<QuerySuccess<String>>());
      expect(state2, isA<QuerySuccess<String>>());
      expect((state1 as QuerySuccess<String>).data, contains('user1'));
      expect((state2 as QuerySuccess<String>).data, contains('user2'));
      expect(MockApiService.callCount, 2);
    });

    test('should reuse same instance for same parameter', () async {
      final provider = queryProviderFamily<String, String>(
        name: 'user-query',
        queryFn: MockApiService.fetchDataWithParam,
        options: const QueryOptions(refetchOnMount: true),
      );
      
      // Listen to same parameter twice
      container.listen(provider('user1'), (previous, next) {});
      container.listen(provider('user1'), (previous, next) {});
      
      // Wait for fetch
      await Future.delayed(const Duration(milliseconds: 150));
      
      expect(MockApiService.callCount, 1); // Only one call
    });

    test('should handle different parameter types', () async {
      final provider = queryProviderFamily<String, int>(
        name: 'id-query',
        queryFn: (id) => MockApiService.fetchDataWithParam(id.toString()),
        options: const QueryOptions(refetchOnMount: true),
      );
      
      // Listen to different IDs
      container.listen(provider(1), (previous, next) {});
      container.listen(provider(2), (previous, next) {});
      
      // Wait for fetches
      await Future.delayed(const Duration(milliseconds: 150));
      
      final state1 = container.read(provider(1));
      final state2 = container.read(provider(2));
      
      expect(state1, isA<QuerySuccess<String>>());
      expect(state2, isA<QuerySuccess<String>>());
      expect((state1 as QuerySuccess<String>).data, contains('1'));
      expect((state2 as QuerySuccess<String>).data, contains('2'));
    });
  });

  group('queryProviderWithParams', () {
    late ProviderContainer container;
    
    setUp(() {
      MockApiService.reset();
      container = ProviderContainer();
      getGlobalQueryCache().clear();
    });
    
    tearDown(() {
      container.dispose();
    });

    test('should create provider with fixed parameters', () async {
      const params = 'fixed-param';
      
      final provider = queryProviderWithParams<String, String>(
        name: 'fixed-query',
        params: params,
        queryFn: MockApiService.fetchDataWithParam,
        options: const QueryOptions(refetchOnMount: true),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait for fetch
      await Future.delayed(const Duration(milliseconds: 150));
      
      final state = container.read(provider);
      expect(state, isA<QuerySuccess<String>>());
      expect((state as QuerySuccess<String>).data, contains('fixed-param'));
      expect(MockApiService.callCount, 1);
    });

    test('should include parameters in query key', () async {
      const params = 'test-param';
      
      final provider = queryProviderWithParams<String, String>(
        name: 'param-query',
        params: params,
        queryFn: MockApiService.fetchDataWithParam,
        options: const QueryOptions(refetchOnMount: true),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait for fetch
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Check cache key includes parameters
      final cache = getGlobalQueryCache();
      final keys = cache.keys;
      expect(keys.any((key) => key.contains('param-query') && key.contains('test-param')), true);
    });
  });

  group('Lifecycle Integration', () {
    late ProviderContainer container;
    
    setUp(() {
      MockApiService.reset();
      container = ProviderContainer();
      getGlobalQueryCache().clear();
    });
    
    tearDown(() {
      container.dispose();
    });

    test('should handle app lifecycle changes', () async {
      final provider = queryProvider<String>(
        name: 'lifecycle-query',
        queryFn: MockApiService.fetchData,
        options: const QueryOptions(
          refetchOnMount: true,
          refetchOnAppFocus: true,
          pauseRefetchInBackground: true,
        ),
      );
      
      // Listen to trigger the provider
      container.listen(provider, (previous, next) {});
      
      // Wait for initial fetch
      await Future.delayed(const Duration(milliseconds: 150));
      
      expect(MockApiService.callCount, 1);
      
      // Simulate app going to background
      final lifecycleManager = AppLifecycleManager.instance;
      lifecycleManager.didChangeAppLifecycleState(AppLifecycleState.paused);
      
      // Simulate app coming back to foreground with stale data
      // First make data stale by manipulating cache
      final cache = getGlobalQueryCache();
      final entry = cache.get<String>('lifecycle-query');
      if (entry != null) {
        final staleEntry = QueryCacheEntry<String>(
          data: entry.data,
          fetchedAt: DateTime.now().subtract(const Duration(minutes: 10)),
          options: const QueryOptions(staleTime: Duration(minutes: 5)),
        );
        cache.set('lifecycle-query', staleEntry);
      }
      
      lifecycleManager.didChangeAppLifecycleState(AppLifecycleState.resumed);
      
      // Wait for potential refetch
      await Future.delayed(const Duration(milliseconds: 150));
      
      // Should have refetched due to stale data
      expect(MockApiService.callCount, 2);
    });
  });
}
