import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mutation_options.dart';
import 'query_client.dart';
import 'query_state.dart';

/// Notifier for managing mutation state
class MutationNotifier<TData, TVariables> extends Notifier<MutationState<TData>>
    with QueryClientMixin {
  MutationNotifier({
    required this.mutationFunction,
    required this.options,
  }) : super();

  @override
  MutationState<TData> build() {
    return const MutationIdle();
  }

  final MutationFunctionWithRef<TData, TVariables> mutationFunction;
  final MutationOptions<TData, TVariables, TVariables> options;

  int _retryCount = 0;

  void _safeState(MutationState<TData> state) {
    this.state = state;
  }

  /// Execute the mutation
  Future<TData> mutate(TVariables variables) async {
    _safeState(const MutationLoading());

    try {
      // Call onMutate callback for optimistic updates
      await options.onMutate?.call(ref, variables, variables);

      final data = await mutationFunction(ref, variables);
      _safeState(MutationSuccess(data));
      _retryCount = 0;

      // Call success callback
      options.onSuccess?.call(ref, data, variables, variables);

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

      _safeState(MutationError(error, stackTrace: stackTrace));
      _retryCount = 0;

      // Call error callback
      options.onError?.call(ref, variables, variables, error, stackTrace);

      rethrow;
    }
  }

  /// Reset the mutation state to idle
  void reset() {
    _safeState(const MutationIdle());
    _retryCount = 0;
  }
}

class MutationNotifierAutoDispose<TData, TVariables>
    extends AutoDisposeNotifier<MutationState<TData>> with QueryClientMixin {
  MutationNotifierAutoDispose({
    required this.mutationFunction,
    required this.options,
  }) : super();

  @override
  MutationState<TData> build() {
    return const MutationIdle();
  }

  final MutationFunctionWithRef<TData, TVariables> mutationFunction;
  final MutationOptions<TData, TVariables, TVariables> options;

  int _retryCount = 0;

  void _safeState(MutationState<TData> state) {
    this.state = state;
  }

  /// Execute the mutation
  Future<TData> mutate(TVariables variables) async {
    _safeState(const MutationLoading());

    try {
      // Call onMutate callback for optimistic updates
      await options.onMutate?.call(ref, variables, variables);

      final data = await mutationFunction(ref, variables);
      _safeState(MutationSuccess(data));
      _retryCount = 0;

      // Call success callback
      options.onSuccess?.call(ref, data, variables, variables);

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

      _safeState(MutationError(error, stackTrace: stackTrace));
      _retryCount = 0;

      // Call error callback
      options.onError?.call(ref, variables, variables, error, stackTrace);

      rethrow;
    }
  }

  /// Reset the mutation state to idle
  void reset() {
    _safeState(const MutationIdle());
    _retryCount = 0;
  }
}

/// Family Notifier for managing mutation state with parameters
class MutationNotifierFamily<TData, TVariables, TParam>
    extends FamilyNotifier<MutationState<TData>, TParam> with QueryClientMixin {
  MutationNotifierFamily({
    required this.mutationFunction,
    required this.options,
  });

  @override
  MutationState<TData> build(TParam param) {
    return const MutationIdle();
  }

  final MutationFunctionWithRefAndParam<TData, TVariables, TParam>
      mutationFunction;
  final MutationOptions<TData, TVariables, TParam> options;

  int _retryCount = 0;

  void _safeState(MutationState<TData> newState) {
    state = newState;
  }

  /// Execute the mutation
  Future<TData> mutate(TVariables variables) async {
    _safeState(const MutationLoading());

    try {
      // Call onMutate callback for optimistic updates
      await options.onMutate?.call(ref, variables, arg);

      final data = await mutationFunction(ref, variables, arg);
      _safeState(MutationSuccess(data));
      _retryCount = 0;

      // Call success callback
      options.onSuccess?.call(ref, data, variables, arg);

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

      _safeState(MutationError(error, stackTrace: stackTrace));
      _retryCount = 0;

      // Call error callback
      options.onError?.call(ref, variables, arg, error, stackTrace);

      rethrow;
    }
  }

  /// Reset the mutation state to idle
  void reset() {
    _safeState(const MutationIdle());
    _retryCount = 0;
  }
}

/// Auto-dispose Family Notifier for managing mutation state with parameters
class MutationNotifierFamilyAutoDispose<TData, TVariables, TParam>
    extends AutoDisposeFamilyNotifier<MutationState<TData>, TParam>
    with QueryClientMixin {
  MutationNotifierFamilyAutoDispose({
    required this.mutationFunction,
    required this.options,
  });

  @override
  MutationState<TData> build(TParam param) {
    return const MutationIdle();
  }

  final MutationFunctionWithRefAndParam<TData, TVariables, TParam>
      mutationFunction;
  final MutationOptions<TData, TVariables, TParam> options;

  int _retryCount = 0;

  void _safeState(MutationState<TData> newState) {
    state = newState;
  }

  /// Execute the mutation
  Future<TData> mutate(TVariables variables) async {
    _safeState(const MutationLoading());

    try {
      // Call onMutate callback for optimistic updates
      await options.onMutate?.call(ref, variables, arg);

      final data = await mutationFunction(ref, variables, arg);
      _safeState(MutationSuccess(data));
      _retryCount = 0;

      // Call success callback
      options.onSuccess?.call(ref, data, variables, arg);

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

      _safeState(MutationError(error, stackTrace: stackTrace));
      _retryCount = 0;

      // Call error callback
      options.onError?.call(ref, variables, arg, error, stackTrace);

      rethrow;
    }
  }

  /// Reset the mutation state to idle
  void reset() {
    _safeState(const MutationIdle());
    _retryCount = 0;
  }
}

/// Provider for creating mutations
NotifierProvider<MutationNotifier<TData, TVariables>,
    MutationState<TData>> createProvider<TData, TVariables>({
  required String name,
  required MutationFunctionWithRef<TData, TVariables> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnSuccessFunctionWithRef<TData, TVariables>? onSuccess,
  OnErrorFunctionWithRef<TData, TVariables>? onError,
  OnMutateFunctionWithRef<TData, TVariables>? onMutate,
}) =>
    NotifierProvider<MutationNotifier<TData, TVariables>, MutationState<TData>>(
      () => MutationNotifier<TData, TVariables>(
        mutationFunction: mutationFn,
        options: MutationOptions(
          retry: retry ?? 0,
          retryDelay: retryDelay ?? const Duration(seconds: 1),
          onSuccess: (ref, data, variables, _) =>
              onSuccess?.call(ref, data, variables),
          onError: (ref, variables, _, error, stackTrace) =>
              onError?.call(ref, variables, error, stackTrace),
          onMutate: (ref, variables, _) =>
              onMutate?.call(ref, variables) ?? Future<void>.value(),
        ),
      ),
      name: name,
    );

/// Modern update mutation provider with family pattern
NotifierProviderFamily<MutationNotifierFamily<TData, TVariables, TParam>,
    MutationState<TData>, TParam> updateProvider<TData, TVariables, TParam>({
  required String name,
  required UpdateMutationFunctionWithRef<TData, TVariables, TParam> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnUpdateSuccessFunctionWithRef<TData, TVariables, TParam>? onSuccess,
  OnUpdateErrorFunctionWithRef<TData, TVariables, TParam>? onError,
  OnUpdateMutateFunctionWithRef<TData, TVariables, TParam>? onMutate,
}) =>
    NotifierProvider.family<MutationNotifierFamily<TData, TVariables, TParam>,
        MutationState<TData>, TParam>(
      () => MutationNotifierFamily<TData, TVariables, TParam>(
        mutationFunction: mutationFn,
        options: MutationOptions(
          retry: retry ?? 0,
          retryDelay: retryDelay ?? const Duration(seconds: 1),
          onSuccess: (ref, data, variables, param) =>
              onSuccess?.call(ref, data, variables, param),
          onError: (ref, variables, param, error, stackTrace) =>
              onError?.call(ref, variables, param, error, stackTrace),
          onMutate: (ref, variables, param) =>
              onMutate?.call(ref, variables, param) ?? Future<void>.value(),
        ),
      ),
      name: name,
    );

NotifierProviderFamily<MutationNotifierFamily<TData, TParam, TParam>,
    MutationState<TData>, TParam> deleteProviderWithParam<TData, TParam>({
  required String name,
  required DeleteMutationFunctionWithRef<TData, TParam> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnSuccessFunctionWithRef<TData, TParam>? onSuccess,
  OnErrorFunctionWithRef<TData, TParam>? onError,
  OnMutateFunctionWithRef<TData, TParam>? onMutate,
}) =>
    NotifierProvider.family<MutationNotifierFamily<TData, TParam, TParam>,
        MutationState<TData>, TParam>(
      () => MutationNotifierFamily<TData, TParam, TParam>(
        mutationFunction: (Ref ref, TParam param, TParam arg) {
          return mutationFn(ref, arg);
        },
        options: MutationOptions(
          retry: retry ?? 0,
          retryDelay: retryDelay ?? const Duration(seconds: 1),
          onSuccess: (ref, data, param, arg) =>
              onSuccess?.call(ref, data, param),
          onError: (ref, param, arg, error, stackTrace) =>
              onError?.call(ref, param, error, stackTrace),
          onMutate: (ref, param, arg) =>
              onMutate?.call(ref, param) ?? Future<void>.value(),
        ),
      ),
      name: name,
    );

// Note: The updateProvider has been simplified to use mutationProviderFamily
// For specialized update functionality, create a custom wrapper

/// Auto-dispose create mutation provider
AutoDisposeNotifierProvider<MutationNotifierAutoDispose<TData, TVariables>,
    MutationState<TData>> createProviderAutoDispose<TData, TVariables>({
  required String name,
  required MutationFunctionWithRef<TData, TVariables> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnSuccessFunctionWithRef<TData, TVariables>? onSuccess,
  OnErrorFunctionWithRef<TData, TVariables>? onError,
  OnMutateFunctionWithRef<TData, TVariables>? onMutate,
}) =>
    AutoDisposeNotifierProvider<MutationNotifierAutoDispose<TData, TVariables>,
        MutationState<TData>>(
      () => MutationNotifierAutoDispose<TData, TVariables>(
        mutationFunction: mutationFn,
        options: MutationOptions(
          retry: retry ?? 0,
          retryDelay: retryDelay ?? const Duration(seconds: 1),
          onSuccess: (ref, data, variables, _) =>
              onSuccess?.call(ref, data, variables),
          onError: (ref, variables, _, error, stackTrace) =>
              onError?.call(ref, variables, error, stackTrace),
          onMutate: (ref, variables, _) =>
              onMutate?.call(ref, variables) ?? Future<void>.value(),
        ),
      ),
      name: name,
    );

/// Auto-dispose delete mutation provider
AutoDisposeNotifierProviderFamily<
    MutationNotifierFamilyAutoDispose<TData, TParam, TParam>,
    MutationState<TData>,
    TParam> deleteProviderAutoDispose<TData, TParam>({
  required String name,
  required DeleteMutationFunctionWithRef<TData, TParam> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnSuccessFunctionWithRef<TData, TParam>? onSuccess,
  OnErrorFunctionWithRef<TData, TParam>? onError,
  OnMutateFunctionWithRef<TData, TParam>? onMutate,
}) =>
    NotifierProvider.autoDispose.family<
        MutationNotifierFamilyAutoDispose<TData, TParam, TParam>,
        MutationState<TData>,
        TParam>(
      () => MutationNotifierFamilyAutoDispose<TData, TParam, TParam>(
        mutationFunction: (Ref ref, TParam param, TParam arg) {
          return mutationFn(ref, arg);
        },
        options: MutationOptions(
          retry: retry ?? 0,
          retryDelay: retryDelay ?? const Duration(seconds: 1),
          onSuccess: (ref, data, param, arg) =>
              onSuccess?.call(ref, data, param),
          onError: (ref, param, arg, error, stackTrace) =>
              onError?.call(ref, arg, error, stackTrace),
          onMutate: (ref, param, arg) =>
              onMutate?.call(ref, arg) ?? Future<void>.value(),
        ),
      ),
      name: name,
    );

/// Auto-dispose update mutation provider
AutoDisposeNotifierProviderFamily<
    MutationNotifierFamilyAutoDispose<TData, TVariables, TParam>,
    MutationState<TData>,
    TParam> updateProviderAutoDispose<TData, TVariables, TParam>({
  required String name,
  required UpdateMutationFunctionWithRef<TData, TVariables, TParam> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnUpdateSuccessFunctionWithRef<TData, TVariables, TParam>? onSuccess,
  OnUpdateErrorFunctionWithRef<TData, TVariables, TParam>? onError,
  OnUpdateMutateFunctionWithRef<TData, TVariables, TParam>? onMutate,
}) =>
    NotifierProvider.autoDispose.family<
        MutationNotifierFamilyAutoDispose<TData, TVariables, TParam>,
        MutationState<TData>,
        TParam>(
      () => MutationNotifierFamilyAutoDispose<TData, TVariables, TParam>(
        mutationFunction: mutationFn,
        options: MutationOptions(
          retry: retry ?? 0,
          retryDelay: retryDelay ?? const Duration(seconds: 1),
          onSuccess: onSuccess,
          onError: onError,
          onMutate: (ref, variables, param) =>
              onMutate?.call(ref, variables, param) ?? Future<void>.value(),
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

extension WidgetRefReadMutationResult on WidgetRef {
  /// Create a mutation result that can be used in widgets (modern version)
  MutationResult<TData, TVariable> readCreateMutationResult<TData, TVariable>(
      NotifierProvider<MutationNotifier<TData, TVariable>, MutationState<TData>>
          provider) {
    final notifier = read(provider.notifier);
    final state = watch(provider);

    return MutationResult<TData, TVariable>(
      state: state,
      mutate: notifier.mutate,
      reset: notifier.reset,
    );
  }

  MutationResult<TData, TVariable>
      readCreateAutoDisposeMutationResult<TData, TVariable>(
          AutoDisposeNotifierProvider<
                  MutationNotifierAutoDispose<TData, TVariable>,
                  MutationState<TData>>
              provider) {
    final notifier = read(provider.notifier);
    final state = watch(provider);

    return MutationResult<TData, TVariable>(
      state: state,
      mutate: notifier.mutate,
      reset: notifier.reset,
    );
  }

  MutationResult<TData, TParam> readDeleteMutationResult<TData, TParam>(
      NotifierProviderFamily<MutationNotifierFamily<TData, TParam, TParam>,
              MutationState<TData>, TParam>
          provider,
      TParam param) {
    final notifier = read(provider(param).notifier);
    final state = watch(provider(param));

    return MutationResult<TData, TParam>(
      state: state,
      mutate: notifier.mutate,
      reset: notifier.reset,
    );
  }

  MutationResult<TData, TParam>
      readDeleteAutoDisposeMutationResult<TData, TParam>(
          AutoDisposeNotifierProviderFamily<
                  MutationNotifierFamilyAutoDispose<TData, TParam, TParam>,
                  MutationState<TData>,
                  TParam>
              provider,
          TParam param) {
    final notifier = read(provider(param).notifier);
    final state = watch(provider(param));

    return MutationResult<TData, TParam>(
      state: state,
      mutate: notifier.mutate,
      reset: notifier.reset,
    );
  }

///
/// ref.readUpdateMutationResult(saveTeamMembersMutationProvider, (
///   locationId: locationId,
///   date: date
/// )).mutate(_teamMemberNotifier.value);
///
  MutationResult<TData, TVariables>
      readUpdateMutationResult<TData, TVariables, TParam>(
          NotifierProviderFamily<
                  MutationNotifierFamily<TData, TVariables, TParam>,
                  MutationState<TData>,
                  TParam>
              provider,
          TParam param) {
    final notifier = read(provider(param).notifier);
    final state = watch(provider(param));

    return MutationResult<TData, TVariables>(
      state: state,
      mutate: notifier.mutate,
      reset: notifier.reset,
    );
  }

  MutationResult<TData, TVariables>
      readUpdateAutoDisposeMutationResult<TData, TVariables, TParam>(
          AutoDisposeNotifierProviderFamily<
                  MutationNotifierFamilyAutoDispose<TData, TVariables, TParam>,
                  MutationState<TData>,
                  TParam>
              provider,
          TParam param) {
    final notifier = read(provider(param).notifier);
    final state = watch(provider(param));

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
  }) =>
      switch (this) {
        MutationIdle<T>() => idle?.call(),
        MutationLoading<T>() => loading?.call(),
        final MutationSuccess<T> successState =>
          success?.call(successState.data),
        final MutationError<T> errorState =>
          error?.call(errorState.error, errorState.stackTrace),
      };

  /// Map the data if the mutation is successful
  MutationState<R> map<R>(R Function(T data) mapper) => switch (this) {
        final MutationSuccess<T> success =>
          MutationSuccess(mapper(success.data)),
        MutationIdle<T>() => MutationIdle<R>(),
        MutationLoading<T>() => MutationLoading<R>(),
        final MutationError<T> error =>
          MutationError<R>(error.error, stackTrace: error.stackTrace),
      };
}
