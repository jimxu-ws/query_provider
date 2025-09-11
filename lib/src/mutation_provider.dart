import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mutation_options.dart';
import 'query_client.dart';
import 'query_state.dart';

/// A function that performs a mutation
typedef MutationFunction<TData, TVariables> = Future<TData> Function(TVariables variables);
/// A function that performs a create mutation with a reference
typedef CreateMutationFunctionWithRef<TData, TVariables> = Future<TData> Function(Ref ref, TVariables variables);
/// A function that performs a update mutation with a reference
typedef UpdateMutationFunctionWithRef<TData, TVariables, TParam> = Future<TData> Function(Ref ref, TVariables variables, TParam param);
/// A function that performs a delete mutation with a reference
typedef DeleteMutationFunctionWithRef<TData, TParam> = Future<TData> Function(Ref ref, TParam param);
/// Callback called on successful mutation
typedef OnSuccessFunctionWithRef<TData, TVariables> = void Function(Ref ref, TData data, TVariables variables);
/// Callback called on mutation error
typedef OnErrorFunctionWithRef<TData, TVariables> = void Function(Ref ref, TVariables variables, Object error, StackTrace? stackTrace);
/// Callback called before mutation starts (useful for optimistic updates)
typedef OnMutateFunctionWithRef<TData, TVariables> = Future<void> Function(Ref ref, TVariables variables);

/// Callback called on successful mutation
typedef OnUpdateSuccessFunctionWithRef<TData, TVariables, TParam> = void Function(Ref ref, TData data, TVariables variables, TParam param);
/// Callback called on mutation error
typedef OnUpdateErrorFunctionWithRef<TData, TVariables, TParam> = void Function(Ref ref, TVariables variables, TParam param, Object error, StackTrace? stackTrace);
/// Callback called before mutation starts (useful for optimistic updates)
typedef OnUpdateMutateFunctionWithRef<TData, TVariables, TParam> = Future<void> Function(Ref ref, TVariables variables, TParam param);

/// Notifier for managing mutation state
class MutationNotifier<TData, TVariables> extends StateNotifier<MutationState<TData>>
    with QueryClientMixin {
  MutationNotifier({
    required this.mutationFunction,
    required this.options,
  }) : super(const MutationIdle());

  final MutationFunction<TData, TVariables> mutationFunction;
  final MutationOptions<TData, TVariables> options;

  int _retryCount = 0;

  /// Execute the mutation
  Future<TData> mutate(TVariables variables) async {
    state = const MutationLoading();

    try {
      // Call onMutate callback for optimistic updates
      await options.onMutate?.call(variables);

      final data = await mutationFunction(variables);
      state = MutationSuccess(data);
      _retryCount = 0;

      // Call success callback
      options.onSuccess?.call(data, variables);

      return data;
    } catch (error, stackTrace) {
      debugPrint('Mutation error: $error');
      debugPrint('Mutation stack trace: $stackTrace');
      if (_retryCount < options.retry) {
        _retryCount++;
        debugPrint('Mutation retrying: $_retryCount');
        await Future<void>.delayed(options.retryDelay);
        return mutate(variables);
      }

      state = MutationError(error, stackTrace: stackTrace);
      _retryCount = 0;

      // Call error callback
      options.onError?.call(variables, error, stackTrace);

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
StateNotifierProvider<MutationNotifier<TData, TVariables>, MutationState<TData>> createProvider<TData, TVariables>({
  required String name,
  required CreateMutationFunctionWithRef<TData, TVariables> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnSuccessFunctionWithRef<TData, TVariables>? onSuccess,
  OnErrorFunctionWithRef<TData, TVariables>? onError,
  OnMutateFunctionWithRef<TData, TVariables>? onMutate,
}) => StateNotifierProvider<MutationNotifier<TData, TVariables>, MutationState<TData>>(
    (ref) => MutationNotifier<TData, TVariables>(
      mutationFunction: (TVariables variables){
        return mutationFn(ref, variables);
      },
      options: MutationOptions(
        retry: retry ?? 0,
        retryDelay: retryDelay ?? const Duration(seconds: 1),
        onSuccess: (data, variables) => onSuccess?.call(ref, data, variables),
        onError: (variables, error, stackTrace) => onError?.call(ref, variables, error, stackTrace),
        onMutate: (variables) => onMutate?.call(ref,variables)??Future<void>.value(),
      ),
    ),
    name: name,
  );

/// Provider for updating mutations with parameters (family pattern)
StateNotifierProviderFamily<MutationNotifier<TData, TVariables>, MutationState<TData>, TParam> updateProviderWithParams<TData, TVariables, TParam>({
  required String name,
  required UpdateMutationFunctionWithRef<TData, TVariables, TParam> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnUpdateSuccessFunctionWithRef<TData, TVariables, TParam>? onSuccess,
  OnUpdateErrorFunctionWithRef<TData, TVariables, TParam>? onError,
  OnUpdateMutateFunctionWithRef<TData, TVariables, TParam>? onMutate,
}) => StateNotifierProvider.family<MutationNotifier<TData, TVariables>, MutationState<TData>, TParam>(
    (ref, TParam param) => MutationNotifier<TData, TVariables>(
      mutationFunction: (TVariables variables) => mutationFn(ref, variables, param),
      options: MutationOptions(
        retry: retry ?? 0,
        retryDelay: retryDelay ?? const Duration(seconds: 1),
        onSuccess: (data, variables) => onSuccess?.call(ref, data, variables, param),
        onError: (variables, error, stackTrace) => onError?.call(ref, variables, param, error, stackTrace),
        onMutate: (variables) => onMutate?.call(ref, variables, param) ?? Future<void>.value(),
      ),
    ),
    name: name,
  );

/// Provider for deleting mutations with parameters (family pattern)
StateNotifierProviderFamily<MutationNotifier<TData, TParam>, MutationState<TData>, TParam> deleteProviderWithParams<TData, TParam>({
  required String name,
  required DeleteMutationFunctionWithRef<TData, TParam> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnSuccessFunctionWithRef<TData, TParam>? onSuccess,
  OnErrorFunctionWithRef<TData, TParam>? onError,
  OnMutateFunctionWithRef<TData, TParam>? onMutate,
}) => StateNotifierProvider.family<MutationNotifier<TData, TParam>, MutationState<TData>, TParam>(
    (ref, TParam param) => MutationNotifier<TData, TParam>(
      mutationFunction: (TParam param){
        return mutationFn(ref, param);
      },
      options: MutationOptions(
        retry: retry ?? 0,
        retryDelay: retryDelay ?? const Duration(seconds: 1),
        onSuccess: (data, param) => onSuccess?.call(ref, data, param),
        onError: (param, error, stackTrace) => onError?.call(ref, param, error, stackTrace),
        onMutate: (param) => onMutate?.call(ref, param) ?? Future<void>.value(),
      ),
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
extension MutationProviderExtension<TData, TVariables, TParam> on StateNotifierProvider<MutationNotifier<TData, TVariables>, MutationState<TData>> {
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
      final MutationSuccess<T> successState => success?.call(successState.data),
      final MutationError<T> errorState => error?.call(errorState.error, errorState.stackTrace),
    };
  

  /// Map the data if the mutation is successful
  MutationState<R> map<R>(R Function(T data) mapper) =>switch (this) {
      final MutationSuccess<T> success => MutationSuccess(mapper(success.data)),
      MutationIdle<T>() => MutationIdle<R>(),
      MutationLoading<T>() => MutationLoading<R>(),
      final MutationError<T> error => MutationError<R>(error.error, stackTrace: error.stackTrace),
    };
}
