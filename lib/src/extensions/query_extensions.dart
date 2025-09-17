import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infinite_query_provider.dart';
import '../modern_mutation_provider.dart';
import '../modern_query_provider.dart';
import '../query_state.dart';

/// Extension methods for easier query usage
extension QueryStateExtensions<T> on QueryState<T> {
  /// Execute a callback when the query has data
  R? when<R>({
    R Function()? idle,
    R Function()? loading,
    R Function(T data)? success,
    R Function(Object error, StackTrace? stackTrace)? error,
    R Function(T data)? refetching,
  }) =>
      switch (this) {
        QueryIdle<T>() => idle?.call(),
        QueryLoading<T>() => loading?.call(),
        final QuerySuccess<T> successState => success?.call(successState.data),
        final QueryError<T> errorState =>
          error?.call(errorState.error, errorState.stackTrace),
        final QueryRefetching<T> refetchingState =>
          refetching?.call(refetchingState.previousData),
      };

  /// Map the data if the query is successful
  QueryState<R> map<R>(R Function(T data) mapper) => switch (this) {
        final QuerySuccess<T> success =>
          QuerySuccess(mapper(success.data), fetchedAt: success.fetchedAt),
        final QueryRefetching<T> refetching => QueryRefetching(
            mapper(refetching.previousData),
            fetchedAt: refetching.fetchedAt),
        QueryIdle<T>() => QueryIdle<R>(),
        QueryLoading<T>() => QueryLoading<R>(),
        final QueryError<T> error =>
          QueryError<R>(error.error, stackTrace: error.stackTrace),
      };
}

/// Extension methods for WidgetRef to make query usage more convenient
extension QueryWidgetRefExtension on WidgetRef {
  /// Watch a query and return its state
  QueryState<T> watchQuery<T>(
          NotifierProvider<QueryNotifier<T>, QueryState<T>> provider) =>
      watch(provider);

  /// Watch a mutation and return its state
  MutationState<T> watchMutation<T, V>(
          NotifierProvider<MutationNotifier<T, V>, MutationState<T>>
              provider) =>
      watch(provider);

  /// Watch an infinite query and return its state
  InfiniteQueryState<T> watchInfiniteQuery<T, P>(
          NotifierProvider<InfiniteQueryNotifier<T, P>, InfiniteQueryState<T>>
              provider) =>
      watch(provider);

  /// Read a query notifier for manual operations
  QueryNotifier<T> readQueryNotifier<T>(
          NotifierProvider<QueryNotifier<T>, QueryState<T>> provider) =>
      read(provider.notifier);

  /// Read an infinite query notifier for manual operations
  InfiniteQueryNotifier<T, P> readInfiniteQueryNotifier<T, P>(
          NotifierProvider<InfiniteQueryNotifier<T, P>, InfiniteQueryState<T>>
              provider) =>
      read(provider.notifier);

  /// Read a notifier for manual operations with safe handling of disposal
  Future<Tr> safeRead<Tn, Tr>(
      Refreshable<Tn> notifier, Future<Tr> Function(Tn) call) async {
    final sub = listenManual(notifier, (_, __) {});
    final res = await call(sub.read());
    sub.close();
    return res;
  }
}

/// Extension methods for Consumer widgets
extension QueryConsumerExtension on Consumer {
  /// Create a consumer that watches a query
  static Widget query<T>({
    required NotifierProvider<QueryNotifier<T>, QueryState<T>> provider,
    required Widget Function(
            BuildContext context, QueryState<T> state, Widget? child)
        builder,
    Key? key,
    Widget? child,
  }) =>
      Consumer(
        key: key,
        builder: (context, ref, child) {
          final state = ref.watch(provider);
          return builder(context, state, child);
        },
        child: child,
      );

  /// Create a consumer that watches a mutation
  static Widget mutation<T, V>({
    required NotifierProvider<MutationNotifier<T, V>, MutationState<T>>
        provider,
    required Widget Function(
            BuildContext context, MutationState<T> state, Widget? child)
        builder,
    Key? key,
    Widget? child,
  }) =>
      Consumer(
        key: key,
        builder: (context, ref, child) {
          final state = ref.watch(provider);
          return builder(context, state, child);
        },
        child: child,
      );

  /// Create a consumer that watches an infinite query
  static Widget infiniteQuery<T, P>({
    required NotifierProvider<InfiniteQueryNotifier<T, P>,
            InfiniteQueryState<T>>
        provider,
    required Widget Function(
            BuildContext context, InfiniteQueryState<T> state, Widget? child)
        builder,
    Key? key,
    Widget? child,
  }) =>
      Consumer(
        key: key,
        builder: (context, ref, child) {
          final state = ref.watch(provider);
          return builder(context, state, child);
        },
        child: child,
      );
}

/// Extension methods for BuildContext to access query operations
extension QueryBuildContextExtension on BuildContext {
  /// Invalidate queries by pattern
  void invalidateQueries(String pattern) {
    // This would need access to the query client
    // Implementation depends on how you want to expose the query client
  }
}

// QueryUtils class moved to riverpod_extensions.dart to avoid naming conflicts

/// Mixin for widgets that use queries
mixin QueryMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// Convenience method to watch a query
  QueryState<R> watchQuery<R>(
          NotifierProvider<QueryNotifier<R>, QueryState<R>> provider) =>
      ref.watch(provider);

  /// Convenience method to watch a mutation
  MutationState<R> watchMutation<R, V>(
          NotifierProvider<MutationNotifier<R, V>, MutationState<R>>
              provider) =>
      ref.watch(provider);

  /// Convenience method to watch an infinite query
  InfiniteQueryState<R> watchInfiniteQuery<R, P>(
          NotifierProvider<InfiniteQueryNotifier<R, P>, InfiniteQueryState<R>>
              provider) =>
      ref.watch(provider);

  /// Convenience method to read a query notifier
  QueryNotifier<R> readQueryNotifier<R>(
          NotifierProvider<QueryNotifier<R>, QueryState<R>> provider) =>
      ref.read(provider.notifier);

  /// Convenience method to read a mutation notifier
  MutationNotifier<R, V> readMutationNotifier<R, V>(
          NotifierProvider<MutationNotifier<R, V>, MutationState<R>>
              provider) =>
      ref.read(provider.notifier);

  /// Convenience method to read an infinite query notifier
  InfiniteQueryNotifier<R, P> readInfiniteQueryNotifier<R, P>(
          NotifierProvider<InfiniteQueryNotifier<R, P>, InfiniteQueryState<R>>
              provider) =>
      ref.read(provider.notifier);
}
