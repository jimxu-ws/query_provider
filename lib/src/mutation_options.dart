import 'package:meta/meta.dart';

/// Callback called on successful mutation
typedef OnSuccessFunction<TData, TVariables> = void Function(TData data, TVariables variables);
/// Callback called on mutation error
typedef OnErrorFunction<TData, TVariables> = void Function(TVariables variables, Object error, StackTrace? stackTrace);
/// Callback called before mutation starts (useful for optimistic updates)
typedef OnMutateFunction<TData, TVariables> = Future<void> Function(TVariables variables);

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
  final OnSuccessFunction<TData, TVariables>? onSuccess;

  /// Callback called on mutation error
  final OnErrorFunction<TData, TVariables>? onError;

  /// Callback called before mutation starts (useful for optimistic updates)
  final OnMutateFunction<TData, TVariables>? onMutate;

  MutationOptions<TData, TVariables> copyWith({
    int? retry,
    Duration? retryDelay,
    OnSuccessFunction<TData, TVariables>? onSuccess,
    OnErrorFunction<TData, TVariables>? onError,
    OnMutateFunction<TData, TVariables>? onMutate,
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
