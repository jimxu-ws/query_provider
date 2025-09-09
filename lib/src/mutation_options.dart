import 'package:meta/meta.dart';

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
  final void Function(TData data, TVariables variables)? onSuccess;

  /// Callback called on mutation error
  final void Function(Object error, TVariables variables, StackTrace? stackTrace)? onError;

  /// Callback called before mutation starts (useful for optimistic updates)
  final Future<void> Function(TVariables variables)? onMutate;

  MutationOptions<TData, TVariables> copyWith({
    int? retry,
    Duration? retryDelay,
    void Function(TData data, TVariables variables)? onSuccess,
    void Function(Object error, TVariables variables, StackTrace? stackTrace)? onError,
    Future<void> Function(TVariables variables)? onMutate,
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
