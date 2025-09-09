import 'package:meta/meta.dart';

/// Represents the state of a query
@immutable
sealed class QueryState<T> {
  const QueryState();

  /// Returns true if the query is currently loading
  bool get isLoading => this is QueryLoading<T>;

  /// Returns true if the query has data
  bool get hasData => this is QuerySuccess<T>;

  /// Returns true if the query has an error
  bool get hasError => this is QueryError<T>;

  /// Returns true if the query is idle (not started)
  bool get isIdle => this is QueryIdle<T>;

  /// Returns true if the query is refetching (has data but loading new data)
  bool get isRefetching => this is QueryRefetching<T>;

  /// Returns the data if available, null otherwise
  T? get data => switch (this) {
        QuerySuccess<T> success => success.data,
        QueryRefetching<T> refetching => refetching.previousData,
        _ => null,
      };

  /// Returns the error if available, null otherwise
  Object? get error => switch (this) {
        QueryError<T> error => error.error,
        _ => null,
      };

  /// Returns the stack trace if available, null otherwise
  StackTrace? get stackTrace => switch (this) {
        QueryError<T> error => error.stackTrace,
        _ => null,
      };
}

/// Initial state before any query is executed
final class QueryIdle<T> extends QueryState<T> {
  const QueryIdle();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is QueryIdle<T>;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'QueryIdle<$T>()';
}

/// State when query is loading for the first time
final class QueryLoading<T> extends QueryState<T> {
  const QueryLoading();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is QueryLoading<T>;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'QueryLoading<$T>()';
}

/// State when query has successfully loaded data
final class QuerySuccess<T> extends QueryState<T> {
  const QuerySuccess(this.data, {this.fetchedAt});

  final T data;
  final DateTime? fetchedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuerySuccess<T> &&
          other.data == data &&
          other.fetchedAt == fetchedAt);

  @override
  int get hashCode => Object.hash(data, fetchedAt);

  @override
  String toString() => 'QuerySuccess<$T>(data: $data, fetchedAt: $fetchedAt)';
}

/// State when query has failed with an error
final class QueryError<T> extends QueryState<T> {
  const QueryError(this.error, {this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueryError<T> &&
          other.error == error &&
          other.stackTrace == stackTrace);

  @override
  int get hashCode => Object.hash(error, stackTrace);

  @override
  String toString() => 'QueryError<$T>(error: $error)';
}

/// State when query is refetching (has previous data but loading new data)
final class QueryRefetching<T> extends QueryState<T> {
  const QueryRefetching(this.previousData, {this.fetchedAt});

  final T previousData;
  final DateTime? fetchedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QueryRefetching<T> &&
          other.previousData == previousData &&
          other.fetchedAt == fetchedAt);

  @override
  int get hashCode => Object.hash(previousData, fetchedAt);

  @override
  String toString() =>
      'QueryRefetching<$T>(previousData: $previousData, fetchedAt: $fetchedAt)';
}

/// Represents the state of a mutation
@immutable
sealed class MutationState<T> {
  const MutationState();

  /// Returns true if the mutation is currently loading
  bool get isLoading => this is MutationLoading<T>;

  /// Returns true if the mutation has succeeded
  bool get isSuccess => this is MutationSuccess<T>;

  /// Returns true if the mutation has an error
  bool get hasError => this is MutationError<T>;

  /// Returns true if the mutation is idle (not started)
  bool get isIdle => this is MutationIdle<T>;

  /// Returns the data if available, null otherwise
  T? get data => switch (this) {
        MutationSuccess<T> success => success.data,
        _ => null,
      };

  /// Returns the error if available, null otherwise
  Object? get error => switch (this) {
        MutationError<T> error => error.error,
        _ => null,
      };
}

/// Initial state before any mutation is executed
final class MutationIdle<T> extends MutationState<T> {
  const MutationIdle();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MutationIdle<T>;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'MutationIdle<$T>()';
}

/// State when mutation is loading
final class MutationLoading<T> extends MutationState<T> {
  const MutationLoading();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is MutationLoading<T>;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'MutationLoading<$T>()';
}

/// State when mutation has succeeded
final class MutationSuccess<T> extends MutationState<T> {
  const MutationSuccess(this.data);

  final T data;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MutationSuccess<T> && other.data == data);

  @override
  int get hashCode => data.hashCode;

  @override
  String toString() => 'MutationSuccess<$T>(data: $data)';
}

/// State when mutation has failed
final class MutationError<T> extends MutationState<T> {
  const MutationError(this.error, {this.stackTrace});

  final Object error;
  final StackTrace? stackTrace;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MutationError<T> &&
          other.error == error &&
          other.stackTrace == stackTrace);

  @override
  int get hashCode => Object.hash(error, stackTrace);

  @override
  String toString() => 'MutationError<$T>(error: $error)';
}
