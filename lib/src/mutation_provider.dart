import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

import 'query_state.dart';
import 'mutation_options.dart';
import 'query_client.dart';

/// A function that performs a mutation
typedef MutationFunction<TData, TVariables> = Future<TData> Function(TVariables variables);

/// Notifier for managing mutation state
class MutationNotifier<TData, TVariables> extends StateNotifier<MutationState<TData>>
    with QueryClientMixin {
  MutationNotifier({
    required this.mutationFn,
    required this.options,
  }) : super(const MutationIdle());

  final MutationFunction<TData, TVariables> mutationFn;
  final MutationOptions<TData, TVariables> options;

  int _retryCount = 0;

  /// Execute the mutation
  Future<TData> mutate(TVariables variables) async {
    state = const MutationLoading();

    try {
      // Call onMutate callback for optimistic updates
      await options.onMutate?.call(variables);

      final data = await mutationFn(variables);
      state = MutationSuccess(data);
      _retryCount = 0;

      // Call success callback
      options.onSuccess?.call(data, variables);

      return data;
    } catch (error, stackTrace) {
      if (_retryCount < options.retry) {
        _retryCount++;
        await Future<void>.delayed(options.retryDelay);
        return mutate(variables);
      }

      state = MutationError(error, stackTrace: stackTrace);
      _retryCount = 0;

      // Call error callback
      options.onError?.call(error, variables, stackTrace);

      rethrow;
    }
  }

  /// Reset the mutation state to idle
  void reset() {
    state = const MutationIdle();
    _retryCount = 0;
  }
}

/// Provider for creating mutations
StateNotifierProvider<MutationNotifier<TData, TVariables>, MutationState<TData>> mutationProvider<TData, TVariables>({
  required String name,
  required MutationFunction<TData, TVariables> mutationFn,
  MutationOptions<TData, TVariables> options = const MutationOptions(),
}) => StateNotifierProvider<MutationNotifier<TData, TVariables>, MutationState<TData>>(
    (ref) => MutationNotifier<TData, TVariables>(
      mutationFn: mutationFn,
      options: options,
    ),
    name: name,
  );

/// Hook-like interface for using mutations
@immutable
class MutationResult<TData, TVariables> {
  const MutationResult({
    required this.state,
    required this.mutate,
    required this.reset,
  });

  final MutationState<TData> state;
  final Future<TData> Function(TVariables variables) mutate;
  final VoidCallback reset;

  /// Returns true if the mutation is currently loading
  bool get isLoading => state.isLoading;

  /// Returns true if the mutation has succeeded
  bool get isSuccess => state.isSuccess;

  /// Returns true if the mutation has an error
  bool get hasError => state.hasError;

  /// Returns true if the mutation is idle
  bool get isIdle => state.isIdle;

  /// Returns the data if available
  TData? get data => state.data;

  /// Returns the error if available
  Object? get error => state.error;
}

/// Extension to create a mutation result from a provider
extension MutationProviderExtension<TData, TVariables> on StateNotifierProvider<MutationNotifier<TData, TVariables>, MutationState<TData>> {
  /// Create a mutation result that can be used in widgets
  MutationResult<TData, TVariables> use(WidgetRef ref) {
    final notifier = ref.read(this.notifier);
    final state = ref.watch(this);

    return MutationResult<TData, TVariables>(
      state: state,
      mutate: notifier.mutate,
      reset: notifier.reset,
    );
  }
}

/// Extension methods for mutation state
extension MutationStateExtensions<T> on MutationState<T> {
  /// Execute a callback based on mutation state
  R? when<R>({
    R Function()? idle,
    R Function()? loading,
    R Function(T data)? success,
    R Function(Object error, StackTrace? stackTrace)? error,
  })=>switch (this) {
      MutationIdle<T>() => idle?.call(),
      MutationLoading<T>() => loading?.call(),
      MutationSuccess<T> successState => success?.call(successState.data),
      MutationError<T> errorState => error?.call(errorState.error, errorState.stackTrace),
    };
  

  /// Map the data if the mutation is successful
  MutationState<R> map<R>(R Function(T data) mapper) =>switch (this) {
      MutationSuccess<T> success => MutationSuccess(mapper(success.data)),
      MutationIdle<T>() => MutationIdle<R>(),
      MutationLoading<T>() => MutationLoading<R>(),
      MutationError<T> error => MutationError<R>(error.error, stackTrace: error.stackTrace),
    };
}
