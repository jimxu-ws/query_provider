import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:query_provider/query_provider.dart';

// Mock mutation functions for testing
class MockMutationService {
  static int callCount = 0;
  static bool shouldFail = false;
  
  static Future<String> createUser(Map<String, dynamic> userData) async {
    await Future.delayed(const Duration(milliseconds: 50),()=>null);
    callCount++;
    
    if (shouldFail) {
      throw Exception('Failed to create user');
    }
    
    return 'User created: ${userData['name']} - $callCount';
  }
  
  static void reset() {
    callCount = 0;
    shouldFail = false;
  }
}

void main() {
  group('MutationProvider', () {
    late ProviderContainer container;
    
    setUp(() {
      MockMutationService.reset();
      container = ProviderContainer();
    });
    
    tearDown(() {
      container.dispose();
    });

    test('should start in idle state', () {
      final provider = createProvider<String, Map<String, dynamic>>(
        name: 'create-user',
        mutationFn: (ref, variables) => MockMutationService.createUser(variables),
      );
      
      final state = container.read(provider);
      expect(state, isA<MutationIdle<String>>());
      expect(state.isIdle, true);
      expect(state.isLoading, false);
    });

    test('should handle successful mutation', () async {
      final provider = createProvider<String, Map<String, dynamic>>(
        name: 'create-user',
        mutationFn: (ref, variables) => MockMutationService.createUser(variables),
      );
      
      final states = <MutationState<String>>[];
      container.listen(provider, (previous, next) {
        states.add(next);
      });
      
      // Trigger mutation
      final result = await container.read(provider.notifier).mutate({
        'name': 'John Doe',
        'email': 'john@example.com',
      });
      
      expect(result, 'User created: John Doe - 1');
      expect(MockMutationService.callCount, 1);
      
      // Check state progression
      expect(states.length, greaterThanOrEqualTo(2));
      expect(states.first, isA<MutationLoading<String>>());
      expect(states.last, isA<MutationSuccess<String>>());
      
      final successState = states.last as MutationSuccess<String>;
      expect(successState.data, 'User created: John Doe - 1');
    });

    test('should handle mutation error', () async {
      MockMutationService.shouldFail = true;
      
      final provider = createProvider<String, Map<String, dynamic>>(
        name: 'create-user',
        mutationFn: (ref, variables) => MockMutationService.createUser(variables),
      );
      
      final states = <MutationState<String>>[];
      container.listen(provider, (previous, next) {
        states.add(next);
      });
      
      // Trigger mutation and expect error
      expect(
        () => container.read(provider.notifier).mutate({'name': 'John Doe'}),
        throwsA(isA<Exception>()),
      );
      
      await Future.delayed(const Duration(milliseconds: 100),()=>null);
      
      expect(MockMutationService.callCount, 1);
      
      // Check state progression
      expect(states.length, greaterThanOrEqualTo(2));
      expect(states.first, isA<MutationLoading<String>>());
      expect(states.last, isA<MutationError<String>>());
      
      final errorState = states.last as MutationError<String>;
      expect(errorState.error.toString(), contains('Failed to create user'));
    });

    test('should reset mutation state', () async {
      final provider = createProvider<String, Map<String, dynamic>>(
        name: 'create-user',
        mutationFn: (ref, variables) => MockMutationService.createUser(variables),
      );
      
      // Perform mutation
      await container.read(provider.notifier).mutate({'name': 'John Doe'});
      
      var state = container.read(provider);
      expect(state, isA<MutationSuccess<String>>());
      
      // Reset
      container.read(provider.notifier).reset();
      
      state = container.read(provider);
      expect(state, isA<MutationIdle<String>>());
    });
  });

  group('MutationState', () {
    test('MutationIdle should have correct properties', () {
      const state = MutationIdle<String>();
      
      expect(state.isIdle, true);
      expect(state.isLoading, false);
      expect(state.data, null);
      expect(state.error, null);
    });

    test('MutationLoading should have correct properties', () {
      const state = MutationLoading<String>();
      
      expect(state.isIdle, false);
      expect(state.isLoading, true);
      expect(state.data, null);
      expect(state.error, null);
    });

    test('MutationSuccess should have correct properties', () {
      const state = MutationSuccess<String>('success data');
      
      expect(state.isIdle, false);
      expect(state.isLoading, false);
      expect(state.data, 'success data');
      expect(state.error, null);
    });

    test('MutationError should have correct properties', () {
      final error = Exception('test error');
      final state = MutationError<String>(error);
      
      expect(state.isIdle, false);
      expect(state.isLoading, false);
      expect(state.data, null);
      expect(state.error, error);
    });

    test('when method should call correct callbacks', () {
      const idleState = MutationIdle<String>();
      const loadingState = MutationLoading<String>();
      const successState = MutationSuccess<String>('data');
      final errorState = MutationError<String>(Exception('error'));
      
      expect(
        idleState.when(
          idle: () => 'idle',
          loading: () => 'loading',
          success: (data) => 'success',
          error: (error, stackTrace) => 'error',
        ),
        'idle',
      );
      
      expect(
        loadingState.when(
          idle: () => 'idle',
          loading: () => 'loading',
          success: (data) => 'success',
          error: (error, stackTrace) => 'error',
        ),
        'loading',
      );
      
      expect(
        successState.when(
          idle: () => 'idle',
          loading: () => 'loading',
          success: (data) => 'success: $data',
          error: (error, stackTrace) => 'error',
        ),
        'success: data',
      );
      
      expect(
        errorState.when(
          idle: () => 'idle',
          loading: () => 'loading',
          success: (data) => 'success',
          error: (error, stackTrace) => 'error: $error',
        ),
        'error: Exception: error',
      );
    });
  });
}
