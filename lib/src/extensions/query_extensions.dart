import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../infinite_query_provider.dart';
import '../mutation_provider.dart';
import '../query_provider.dart';
import '../query_state.dart';

/// Extension methods for WidgetRef to make query usage more convenient
extension QueryWidgetRefExtension on WidgetRef {
  /// Watch a query and return its state
  QueryState<T> watchQuery<T>(StateNotifierProvider<QueryNotifier<T>, QueryState<T>> provider) => watch(provider);

  /// Watch a mutation and return its state
  MutationState<T> watchMutation<T, V>(StateNotifierProvider<MutationNotifier<T, V>, MutationState<T>> provider) => watch(provider);

  /// Watch an infinite query and return its state
  InfiniteQueryState<T> watchInfiniteQuery<T, P>(StateNotifierProvider<InfiniteQueryNotifier<T, P>, InfiniteQueryState<T>> provider) => watch(provider);

  /// Read a query notifier for manual operations
  QueryNotifier<T> readQueryNotifier<T>(StateNotifierProvider<QueryNotifier<T>, QueryState<T>> provider) => read(provider.notifier);

  /// Read a mutation notifier for manual operations
  MutationNotifier<T, V> readMutationNotifier<T, V>(StateNotifierProvider<MutationNotifier<T, V>, MutationState<T>> provider) => read(provider.notifier);

  /// Read an infinite query notifier for manual operations
  InfiniteQueryNotifier<T, P> readInfiniteQueryNotifier<T, P>(StateNotifierProvider<InfiniteQueryNotifier<T, P>, InfiniteQueryState<T>> provider) => read(provider.notifier);
}

/// Extension methods for Consumer widgets
extension QueryConsumerExtension on Consumer {
  /// Create a consumer that watches a query
  static Widget query<T>({
    required StateNotifierProvider<QueryNotifier<T>, QueryState<T>> provider, required Widget Function(BuildContext context, QueryState<T> state, Widget? child) builder, Key? key,
    Widget? child,
  }) => Consumer(
      key: key,
      builder: (context, ref, child) {
        final state = ref.watch(provider);
        return builder(context, state, child);
      },
      child: child,
    );

  /// Create a consumer that watches a mutation
  static Widget mutation<T, V>({
    required StateNotifierProvider<MutationNotifier<T, V>, MutationState<T>> provider, required Widget Function(BuildContext context, MutationState<T> state, Widget? child) builder, Key? key,
    Widget? child,
  }) => Consumer(
      key: key,
      builder: (context, ref, child) {
        final state = ref.watch(provider);
        return builder(context, state, child);
      },
      child: child,
    );

  /// Create a consumer that watches an infinite query
  static Widget infiniteQuery<T, P>({
    required StateNotifierProvider<InfiniteQueryNotifier<T, P>, InfiniteQueryState<T>> provider, required Widget Function(BuildContext context, InfiniteQueryState<T> state, Widget? child) builder, Key? key,
    Widget? child,
  }) => Consumer(
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
  QueryState<R> watchQuery<R>(StateNotifierProvider<QueryNotifier<R>, QueryState<R>> provider) => ref.watch(provider);

  /// Convenience method to watch a mutation
  MutationState<R> watchMutation<R, V>(StateNotifierProvider<MutationNotifier<R, V>, MutationState<R>> provider) => ref.watch(provider);

  /// Convenience method to watch an infinite query
  InfiniteQueryState<R> watchInfiniteQuery<R, P>(StateNotifierProvider<InfiniteQueryNotifier<R, P>, InfiniteQueryState<R>> provider) => ref.watch(provider);

  /// Convenience method to read a query notifier
  QueryNotifier<R> readQueryNotifier<R>(StateNotifierProvider<QueryNotifier<R>, QueryState<R>> provider) => ref.read(provider.notifier);

  /// Convenience method to read a mutation notifier
  MutationNotifier<R, V> readMutationNotifier<R, V>(StateNotifierProvider<MutationNotifier<R, V>, MutationState<R>> provider) => ref.read(provider.notifier);

  /// Convenience method to read an infinite query notifier
  InfiniteQueryNotifier<R, P> readInfiniteQueryNotifier<R, P>(StateNotifierProvider<InfiniteQueryNotifier<R, P>, InfiniteQueryState<R>> provider) => ref.read(provider.notifier);
}
