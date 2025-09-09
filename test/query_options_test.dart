import 'package:flutter_test/flutter_test.dart';
import 'package:query_provider/query_provider.dart';

void main() {
  group('QueryOptions', () {
    test('should have default values', () {
      const options = QueryOptions<String>();
      
      expect(options.staleTime, const Duration(minutes: 5));
      expect(options.cacheTime, const Duration(minutes: 30));
      expect(options.refetchOnMount, true);
      expect(options.refetchOnWindowFocus, false);
      expect(options.refetchInterval, null);
      expect(options.retry, 3);
      expect(options.retryDelay, const Duration(seconds: 1));
      expect(options.enabled, true);
      expect(options.keepPreviousData, false);
    });

    test('copyWith should work correctly', () {
      const options = QueryOptions<String>();
      
      final updated = options.copyWith(
        staleTime: const Duration(minutes: 10),
        cacheTime: const Duration(hours: 1),
        refetchOnMount: false,
        enabled: false,
      );
      
      expect(updated.staleTime, const Duration(minutes: 10));
      expect(updated.cacheTime, const Duration(hours: 1));
      expect(updated.refetchOnMount, false);
      expect(updated.enabled, false);
      // Other values should remain default
      expect(updated.retry, 3);
      expect(updated.keepPreviousData, false);
    });

    test('equality should work correctly', () {
      const options1 = QueryOptions<String>();
      const options2 = QueryOptions<String>();
      const options3 = QueryOptions<String>(staleTime: Duration(minutes: 10));
      
      expect(options1, equals(options2));
      expect(options1, isNot(equals(options3)));
    });
  });

  group('InfiniteQueryOptions', () {
    test('should extend QueryOptions', () {
      final options = InfiniteQueryOptions<String, int>(
        getNextPageParam: (lastPage, allPages) => allPages.length + 1,
      );
      
      expect(options.staleTime, const Duration(minutes: 5));
      expect(options.cacheTime, const Duration(minutes: 30));
      expect(options.getNextPageParam('test', ['page1']), 2);
    });

    test('copyWith should work correctly', () {
      final options = InfiniteQueryOptions<String, int>(
        getNextPageParam: (lastPage, allPages) => allPages.length + 1,
      );
      
      final updated = options.copyWith(
        staleTime: const Duration(minutes: 10),
        getNextPageParam: (lastPage, allPages) => 999,
      );
      
      expect(updated.staleTime, const Duration(minutes: 10));
      expect(updated.getNextPageParam('test', []), 999);
    });

    test('getPreviousPageParam should work correctly', () {
      final options = InfiniteQueryOptions<String, String>(
        getNextPageParam: (lastPage, allPages) => 'next-${allPages.length}',
        getPreviousPageParam: (firstPage, allPages) => 'prev-${allPages.length}',
      );
      
      expect(options.getPreviousPageParam!('first', ['page1']), 'prev-1');
    });
  });
}
