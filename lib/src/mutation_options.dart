import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';

/// Callback called on successful mutation
typedef OnSuccessFunctionWithRef<TData, TVariables> = void Function(Ref ref, TData data, TVariables variables);
/// Callback called on mutation error
typedef OnErrorFunctionWithRef<TData, TVariables> = void Function(Ref ref, TVariables variables, Object error, StackTrace? stackTrace);
/// Callback called before mutation starts (useful for optimistic updates)
typedef OnMutateFunctionWithRef<TData, TVariables> = Future<void> Function(Ref ref, TVariables variables);

/// A function that performs a mutation
typedef MutationFunctionWithRef<TData, TVariables> = Future<TData> Function(Ref ref, TVariables variables);
/// A function that performs a create mutation with a reference
typedef CreateMutationFunctionWithRef<TData, TVariables> = Future<TData> Function(Ref ref, TVariables variables);
/// A function that performs a update mutation with a reference
typedef UpdateMutationFunctionWithRef<TData, TVariables, TParam> = Future<TData> Function(Ref ref, TVariables variables, TParam param);
/// A function that performs a delete mutation with a reference
typedef DeleteMutationFunctionWithRef<TData, TParam> = Future<TData> Function(Ref ref, TParam param);
/// Callback called on successful mutation
typedef OnUpdateSuccessFunctionWithRef<TData, TVariables, TParam> = void Function(Ref ref, TData data, TVariables variables, TParam param);
/// Callback called on mutation error
typedef OnUpdateErrorFunctionWithRef<TData, TVariables, TParam> = void Function(Ref ref, TVariables variables, TParam param, Object error, StackTrace? stackTrace);
/// Callback called before mutation starts (useful for optimistic updates)
typedef OnUpdateMutateFunctionWithRef<TData, TVariables, TParam> = Future<void> Function(Ref ref, TVariables variables, TParam param);

/// Configuration options for a mutation
@immutable
class MutationOptions<TData, TVariables> {
  const MutationOptions({
    this.retry = 0,
    this.retryDelay = const Duration(seconds: 1),
    this.onSuccess,
    this.onError,
    this.onMutate,
  });

  /// Number of retry attempts on failure
  final int retry;

  /// Delay between retry attempts
  final Duration retryDelay;

  /// Callback called on successful mutation
  final OnSuccessFunctionWithRef<TData, TVariables>? onSuccess;

  /// Callback called on mutation error
  final OnErrorFunctionWithRef<TData, TVariables>? onError;

  /// Callback called before mutation starts (useful for optimistic updates)
  final OnMutateFunctionWithRef<TData, TVariables>? onMutate;

  MutationOptions<TData, TVariables> copyWith({
    int? retry,
    Duration? retryDelay,
    OnSuccessFunctionWithRef<TData, TVariables>? onSuccess,
    OnErrorFunctionWithRef<TData, TVariables>? onError,
    OnMutateFunctionWithRef<TData, TVariables>? onMutate,
  }) => MutationOptions<TData, TVariables>(
      retry: retry ?? this.retry,
      retryDelay: retryDelay ?? this.retryDelay,
      onSuccess: onSuccess ?? this.onSuccess,
      onError: onError ?? this.onError,
      onMutate: onMutate ?? this.onMutate,
    );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MutationOptions<TData, TVariables> &&
          other.retry == retry &&
          other.retryDelay == retryDelay);

  @override
  int get hashCode => Object.hash(retry, retryDelay);

  @override
  String toString() => 'MutationOptions<$TData, $TVariables>('
      'retry: $retry, '
      'retryDelay: $retryDelay)';
}
