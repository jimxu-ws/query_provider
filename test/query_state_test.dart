import 'package:flutter_test/flutter_test.dart';
import 'package:query_provider/query_provider.dart';

void main() {
  group('QueryState', () {
    group('QueryIdle', () {
      test('should create idle state', () {
        const state = QueryIdle<String>();
        
        expect(state.hasData, false);
        expect(state.hasError, false);
        expect(state.isLoading, false);
        expect(state.isIdle, true);
        expect(state.data, null);
        expect(state.error, null);
      });

      test('should have correct string representation', () {
        const state = QueryIdle<String>();
        expect(state.toString(), 'QueryIdle<String>()');
      });

      test('should be equal to another idle state', () {
        const state1 = QueryIdle<String>();
        const state2 = QueryIdle<String>();
        
        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });
    });

    group('QueryLoading', () {
      test('should create loading state', () {
        const state = QueryLoading<String>();
        
        expect(state.hasData, false);
        expect(state.hasError, false);
        expect(state.isLoading, true);
        expect(state.isIdle, false);
        expect(state.data, null);
        expect(state.error, null);
      });

      test('should have correct string representation', () {
        const state = QueryLoading<String>();
        expect(state.toString(), 'QueryLoading<String>()');
      });

      test('should be equal to another loading state', () {
        const state1 = QueryLoading<String>();
        const state2 = QueryLoading<String>();
        
        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });
    });

    group('QuerySuccess', () {
      test('should create success state with data', () {
        final now = DateTime.now();
        final state = QuerySuccess('test data', fetchedAt: now);
        
        expect(state.hasData, true);
        expect(state.hasError, false);
        expect(state.isLoading, false);
        expect(state.isIdle, false);
        expect(state.data, 'test data');
        expect(state.error, null);
        expect(state.fetchedAt, now);
      });

      test('should have correct string representation', () {
        final now = DateTime.now();
        final state = QuerySuccess('test data', fetchedAt: now);
        expect(state.toString(), 'QuerySuccess<String>(data: test data, fetchedAt: $now)');
      });

      test('should be equal to another success state with same data', () {
        final now = DateTime.now();
        final state1 = QuerySuccess('test data', fetchedAt: now);
        final state2 = QuerySuccess('test data', fetchedAt: now);
        
        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('should not be equal to success state with different data', () {
        final now = DateTime.now();
        final state1 = QuerySuccess('test data 1', fetchedAt: now);
        final state2 = QuerySuccess('test data 2', fetchedAt: now);
        
        expect(state1, isNot(equals(state2)));
      });
    });

    group('QueryError', () {
      test('should create error state with error', () {
        final error = Exception('Test error');
        final stackTrace = StackTrace.current;
        final state = QueryError<String>(error, stackTrace: stackTrace);
        
        expect(state.hasData, false);
        expect(state.hasError, true);
        expect(state.isLoading, false);
        expect(state.isIdle, false);
        expect(state.data, null);
        expect(state.error, error);
        expect(state.stackTrace, stackTrace);
      });

      test('should create error state without stack trace', () {
        final error = Exception('Test error');
        final state = QueryError<String>(error);
        
        expect(state.hasData, false);
        expect(state.hasError, true);
        expect(state.error, error);
        expect(state.stackTrace, null);
      });

      test('should have correct string representation', () {
        final error = Exception('Test error');
        final state = QueryError<String>(error);
        expect(state.toString(), 'QueryError<String>(error: $error)');
      });

      test('should be equal to another error state with same error', () {
        final error = Exception('Test error');
        final state1 = QueryError<String>(error);
        final state2 = QueryError<String>(error);
        
        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });
    });

    group('QueryRefetching', () {
      test('should create refetching state with previous data', () {
        final now = DateTime.now();
        final state = QueryRefetching('previous data', fetchedAt: now);
        
        expect(state.hasData, false); // QueryRefetching is not QuerySuccess
        expect(state.hasError, false);
        expect(state.isLoading, false);
        expect(state.isIdle, false);
        expect(state.previousData, 'previous data');
        expect(state.error, null);
        expect(state.previousData, 'previous data');
        expect(state.fetchedAt, now);
      });

      test('should have correct string representation', () {
        final now = DateTime.now();
        final state = QueryRefetching('previous data', fetchedAt: now);
        expect(state.toString(), 'QueryRefetching<String>(previousData: previous data, fetchedAt: $now)');
      });

      test('should be equal to another refetching state with same data', () {
        final now = DateTime.now();
        final state1 = QueryRefetching('previous data', fetchedAt: now);
        final state2 = QueryRefetching('previous data', fetchedAt: now);
        
        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });
    });

    group('QueryStateExtensions', () {
      test('when method should call appropriate callback for idle state', () {
        const state = QueryIdle<String>();
        var idleCalled = false;
        
        state.when(
          idle: () {
            idleCalled = true;
            return 'idle';
          },
          loading: () => 'loading',
          success: (data) => 'success',
          error: (error, stackTrace) => 'error',
          refetching: (data) => 'refetching',
        );
        
        expect(idleCalled, true);
      });

      test('when method should call appropriate callback for loading state', () {
        const state = QueryLoading<String>();
        var loadingCalled = false;
        
        state.when(
          idle: () => 'idle',
          loading: () {
            loadingCalled = true;
            return 'loading';
          },
          success: (data) => 'success',
          error: (error, stackTrace) => 'error',
          refetching: (data) => 'refetching',
        );
        
        expect(loadingCalled, true);
      });

      test('when method should call appropriate callback for success state', () {
        final state = QuerySuccess('test data', fetchedAt: DateTime.now());
        var successCalled = false;
        String? receivedData;
        
        state.when(
          idle: () => 'idle',
          loading: () => 'loading',
          success: (data) {
            successCalled = true;
            receivedData = data;
            return 'success';
          },
          error: (error, stackTrace) => 'error',
          refetching: (data) => 'refetching',
        );
        
        expect(successCalled, true);
        expect(receivedData, 'test data');
      });

      test('when method should call appropriate callback for error state', () {
        final error = Exception('Test error');
        final state = QueryError<String>(error);
        var errorCalled = false;
        Object? receivedError;
        
        state.when(
          idle: () => 'idle',
          loading: () => 'loading',
          success: (data) => 'success',
          error: (err, stackTrace) {
            errorCalled = true;
            receivedError = err;
            return 'error';
          },
          refetching: (data) => 'refetching',
        );
        
        expect(errorCalled, true);
        expect(receivedError, error);
      });

      test('when method should call appropriate callback for refetching state', () {
        final state = QueryRefetching('previous data', fetchedAt: DateTime.now());
        var refetchingCalled = false;
        String? receivedData;
        
        state.when(
          idle: () => 'idle',
          loading: () => 'loading',
          success: (data) => 'success',
          error: (error, stackTrace) => 'error',
          refetching: (data) {
            refetchingCalled = true;
            receivedData = data;
            return 'refetching';
          },
        );
        
        expect(refetchingCalled, true);
        expect(receivedData, 'previous data');
      });

      test('map method should transform success state data', () {
        final state = QuerySuccess(5, fetchedAt: DateTime.now());
        final mappedState = state.map<String>((data) => 'Number: $data');
        
        expect(mappedState, isA<QuerySuccess<String>>());
        expect((mappedState as QuerySuccess<String>).data, 'Number: 5');
      });

      test('map method should transform refetching state data', () {
        final state = QueryRefetching(5, fetchedAt: DateTime.now());
        final mappedState = state.map<String>((data) => 'Number: $data');
        
        expect(mappedState, isA<QueryRefetching<String>>());
        expect((mappedState as QueryRefetching<String>).previousData, 'Number: 5');
      });

      test('map method should preserve idle state', () {
        const state = QueryIdle<int>();
        final mappedState = state.map<String>((data) => 'Number: $data');
        
        expect(mappedState, isA<QueryIdle<String>>());
      });

      test('map method should preserve loading state', () {
        const state = QueryLoading<int>();
        final mappedState = state.map<String>((data) => 'Number: $data');
        
        expect(mappedState, isA<QueryLoading<String>>());
      });

      test('map method should preserve error state', () {
        final error = Exception('Test error');
        final state = QueryError<int>(error);
        final mappedState = state.map<String>((data) => 'Number: $data');
        
        expect(mappedState, isA<QueryError<String>>());
        expect((mappedState as QueryError<String>).error, error);
      });
    });
  });
}
