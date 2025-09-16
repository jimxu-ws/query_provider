import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mutation_options.dart';
import 'query_client.dart';
import 'query_state.dart';

@immutable
class UpdateMutationOptions<TData, TVariables, TParam> {
  const UpdateMutationOptions({
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
  final OnUpdateSuccessFunctionWithRef<TData, TVariables, TParam>? onSuccess;

  /// Callback called on mutation error
  final OnUpdateErrorFunctionWithRef<TData, TVariables, TParam>? onError;

  /// Callback called before mutation starts (useful for optimistic updates)
  final OnUpdateMutateFunctionWithRef<TData, TVariables, TParam>? onMutate;

  UpdateMutationOptions<TData, TVariables, TParam> copyWith({
    int? retry,
    Duration? retryDelay,
    OnUpdateSuccessFunctionWithRef<TData, TVariables, TParam>? onSuccess,
    OnUpdateErrorFunctionWithRef<TData, TVariables, TParam>? onError,
    OnUpdateMutateFunctionWithRef<TData, TVariables, TParam>? onMutate,
  }) => UpdateMutationOptions<TData, TVariables, TParam>(
      retry: retry ?? this.retry,
      retryDelay: retryDelay ?? this.retryDelay,
      onSuccess: onSuccess ?? this.onSuccess,
      onError: onError ?? this.onError,
      onMutate: onMutate ?? this.onMutate,
    );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpdateMutationOptions<TData, TVariables, TParam> &&
          other.retry == retry &&
          other.retryDelay == retryDelay);

  @override
  int get hashCode => Object.hash(retry, retryDelay);

  @override
  String toString() => 'UpdateMutationOptions<$TData, $TVariables, $TParam>('
      'retry: $retry, '
      'retryDelay: $retryDelay)';
}

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
  final MutationOptions<TData, TVariables> options;

  int _retryCount = 0;

  void _safeState(MutationState<TData> state) {
    this.state = state;
  }

  /// Execute the mutation
  Future<TData> mutate(TVariables variables) async {
    _safeState(const MutationLoading());

    try {
      // Call onMutate callback for optimistic updates
      await options.onMutate?.call(ref,variables);

      final data = await mutationFunction(ref,variables);
      _safeState(MutationSuccess(data));
      _retryCount = 0;

      // Call success callback
      options.onSuccess?.call(ref, data, variables);

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
      options.onError?.call(ref, variables, error, stackTrace);

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
class UpdateMutationNotifierFamily<TData, TVariables, TParam> extends FamilyNotifier<MutationState<TData>, TParam>
    with QueryClientMixin {
  UpdateMutationNotifierFamily({
    required this.mutationFunction,
    required this.options,
  });

  @override
  MutationState<TData> build(TParam param) {
    return const MutationIdle();
  }

  final UpdateMutationFunctionWithRef<TData, TVariables, TParam> mutationFunction;
  final UpdateMutationOptions<TData, TVariables, TParam> options;
  
  int _retryCount = 0;

  void _safeState(MutationState<TData> newState) {
    state = newState;
  }

  /// Execute the mutation
  Future<TData> mutate(TVariables variables, TParam param) async {
    _safeState(const MutationLoading());

    try {
      // Call onMutate callback for optimistic updates
      await options.onMutate?.call(ref, variables, param);

      final data = await mutationFunction(ref, variables, param);
      _safeState(MutationSuccess(data));
      _retryCount = 0;

      // Call success callback
      options.onSuccess?.call(ref, data, variables, param);

      return data;
    } catch (error, stackTrace) {
      debugPrint('Mutation error: $error');
      debugPrint('Mutation stack trace: $stackTrace');
      if (_retryCount < options.retry) {
        _retryCount++;
        debugPrint('Mutation retrying: $_retryCount');
        await Future<void>.delayed(options.retryDelay);
        return mutate(variables, param);
      }

      _safeState(MutationError(error, stackTrace: stackTrace));
      _retryCount = 0;

      // Call error callback
      options.onError?.call(ref, variables, param, error, stackTrace);

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
class MutationNotifierFamily<TData, TVariables, TParam> extends FamilyNotifier<MutationState<TData>, TParam>
    with QueryClientMixin {
  MutationNotifierFamily({
    required this.mutationFunction,
    required this.options,
  });

  @override
  MutationState<TData> build(TParam param) {
    return const MutationIdle();
  }

  final MutationFunctionWithRef<TData, TVariables> mutationFunction;
  final MutationOptions<TData, TVariables> options;
  
  int _retryCount = 0;

  void _safeState(MutationState<TData> newState) {
    state = newState;
  }

  /// Execute the mutation
  Future<TData> mutate(TVariables variables) async {
    _safeState(const MutationLoading());

    try {
      // Call onMutate callback for optimistic updates
      await options.onMutate?.call(ref, variables);

      final data = await mutationFunction(ref, variables);
      _safeState(MutationSuccess(data));
      _retryCount = 0;

      // Call success callback
      options.onSuccess?.call(ref, data, variables);

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
      options.onError?.call(ref, variables, error, stackTrace);

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
class MutationNotifierFamilyAutoDispose<TData, TVariables, TParam> extends AutoDisposeFamilyNotifier<MutationState<TData>, TParam>
    with QueryClientMixin {
  MutationNotifierFamilyAutoDispose({
    required this.mutationFunction,
    required this.options,
  });

  @override
  MutationState<TData> build(TParam param) {
    return const MutationIdle();
  }

  final MutationFunctionWithRef<TData, TVariables> mutationFunction;
  final MutationOptions<TData, TVariables> options;
  
  int _retryCount = 0;

  void _safeState(MutationState<TData> newState) {
    state = newState;
  }

  /// Execute the mutation
  Future<TData> mutate(TVariables variables) async {
    _safeState(const MutationLoading());

    try {
      // Call onMutate callback for optimistic updates
      await options.onMutate?.call(ref, variables);

      final data = await mutationFunction(ref, variables);
      _safeState(MutationSuccess(data));
      _retryCount = 0;

      // Call success callback
      options.onSuccess?.call(ref, data, variables);

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
      options.onError?.call(ref, variables, error, stackTrace);

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
class UpdateMutationNotifierFamilyAutoDispose<TData, TVariables, TParam> extends AutoDisposeFamilyNotifier<MutationState<TData>, TParam>
    with QueryClientMixin {
  UpdateMutationNotifierFamilyAutoDispose({
    required this.mutationFunction,
    required this.options,
  });

  @override
  MutationState<TData> build(TParam param) {
    return const MutationIdle();
  }

  final UpdateMutationFunctionWithRef<TData, TVariables, TParam> mutationFunction;
  final UpdateMutationOptions<TData, TVariables, TParam> options;
  
  int _retryCount = 0;

  void _safeState(MutationState<TData> newState) {
    state = newState;
  }

  /// Execute the mutation
  Future<TData> mutate(TVariables variables, TParam param) async {
    _safeState(const MutationLoading());

    try {
      // Call onMutate callback for optimistic updates
      await options.onMutate?.call(ref, variables, param);

      final data = await mutationFunction(ref, variables, param);
      _safeState(MutationSuccess(data));
      _retryCount = 0;

      // Call success callback
      options.onSuccess?.call(ref, data, variables, param);

      return data;
    } catch (error, stackTrace) {
      debugPrint('Mutation error: $error');
      debugPrint('Mutation stack trace: $stackTrace');
      if (_retryCount < options.retry) {
        _retryCount++;
        debugPrint('Mutation retrying: $_retryCount');
        await Future<void>.delayed(options.retryDelay);
        return mutate(variables, param);
      }

      _safeState(MutationError(error, stackTrace: stackTrace));
      _retryCount = 0;

      // Call error callback
      options.onError?.call(ref, variables, param, error, stackTrace);

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
NotifierProvider<MutationNotifier<TData, TVariables>, MutationState<TData>> createProvider<TData, TVariables>({
  required String name,
  required CreateMutationFunctionWithRef<TData, TVariables> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnSuccessFunctionWithRef<TData, TVariables>? onSuccess,
  OnErrorFunctionWithRef<TData, TVariables>? onError,
  OnMutateFunctionWithRef<TData, TVariables>? onMutate,
}) => NotifierProvider<MutationNotifier<TData, TVariables>, MutationState<TData>>(
    () => MutationNotifier<TData, TVariables>(
      mutationFunction: mutationFn,
      options: MutationOptions(
        retry: retry ?? 0,
        retryDelay: retryDelay ?? const Duration(seconds: 1),
        onSuccess: (ref, data, variables) => onSuccess?.call(ref, data, variables),
        onError: (ref,variables, error, stackTrace) => onError?.call(ref, variables, error, stackTrace),
        onMutate: (ref,variables) => onMutate?.call(ref,variables)??Future<void>.value(),
      ),
    ),
    name: name,
  );


/// Modern update mutation provider with family pattern
NotifierProviderFamily<UpdateMutationNotifierFamily<TData, TVariables, TParam>, MutationState<TData>, TParam> updateProvider<TData, TVariables, TParam>({
  required String name,
  required UpdateMutationFunctionWithRef<TData, TVariables, TParam> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnUpdateSuccessFunctionWithRef<TData, TVariables, TParam>? onSuccess,
  OnUpdateErrorFunctionWithRef<TData, TVariables, TParam>? onError,
  OnUpdateMutateFunctionWithRef<TData, TVariables, TParam>? onMutate,
}) => NotifierProvider.family<UpdateMutationNotifierFamily<TData, TVariables, TParam>, MutationState<TData>, TParam>(
    () => UpdateMutationNotifierFamily<TData, TVariables, TParam>(
      mutationFunction: mutationFn,
      options: UpdateMutationOptions(
        retry: retry ?? 0,
        retryDelay: retryDelay ?? const Duration(seconds: 1),
        onSuccess: (ref, data, variables, param) => onSuccess?.call(ref, data,variables, param),
        onError: (ref, variables, param, error, stackTrace) => onError?.call(ref, variables, param, error, stackTrace),
        onMutate: (ref, variables, param) => onMutate?.call(ref, variables, param)??Future<void>.value(),
      ),
    ),
    name: name,
  );

NotifierProviderFamily<MutationNotifierFamily<TData, TParam, TParam>, MutationState<TData>, TParam> deleteProviderWithParam<TData, TParam>({
  required String name,
  required DeleteMutationFunctionWithRef<TData, TParam> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnSuccessFunctionWithRef<TData, TParam>? onSuccess,
  OnErrorFunctionWithRef<TData, TParam>? onError,
  OnMutateFunctionWithRef<TData, TParam>? onMutate,
}) => NotifierProvider.family<MutationNotifierFamily<TData, TParam, TParam>, MutationState<TData>, TParam>(
    () => MutationNotifierFamily<TData, TParam, TParam>(
      mutationFunction: (Ref ref, TParam param){
        return mutationFn(ref, param);
      },
      options: MutationOptions(
        retry: retry ?? 0,
        retryDelay: retryDelay ?? const Duration(seconds: 1),
        onSuccess: (ref, data, param) => onSuccess?.call(ref, data, param),
        onError: (ref, param, error, stackTrace) => onError?.call(ref, param, error, stackTrace),
        onMutate: (ref, param) => onMutate?.call(ref, param)??Future<void>.value(),
      ),
    ),
    name: name,
  );


// Note: The updateProvider has been simplified to use mutationProviderFamily
// For specialized update functionality, create a custom wrapper

/// Auto-dispose create mutation provider
AutoDisposeNotifierProviderFamily<MutationNotifierFamilyAutoDispose<TData, TVariables, TParam>, MutationState<TData>, TParam> createProviderAutoDispose<TData, TVariables, TParam>({
  required String name,
  required CreateMutationFunctionWithRef<TData, TVariables> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnSuccessFunctionWithRef<TData, TVariables>? onSuccess,
  OnErrorFunctionWithRef<TData, TVariables>? onError,
  OnMutateFunctionWithRef<TData, TVariables>? onMutate,
}) => NotifierProvider.autoDispose.family<MutationNotifierFamilyAutoDispose<TData, TVariables, TParam>, MutationState<TData>, TParam>(
    () => MutationNotifierFamilyAutoDispose<TData, TVariables, TParam>(
      mutationFunction: mutationFn,
      options: MutationOptions(
        retry: retry ?? 0,
        retryDelay: retryDelay ?? const Duration(seconds: 1),
        onSuccess: onSuccess,
        onError: onError,
        onMutate: (ref,variables) => onMutate?.call(ref,variables)??Future<void>.value(),
      ),
    ),
    name: name,
  );

/// Auto-dispose delete mutation provider
AutoDisposeNotifierProviderFamily<MutationNotifierFamilyAutoDispose<TData, TParam, TParam>, MutationState<TData>, TParam> deleteProviderAutoDispose<TData, TParam>({
  required String name,
  required DeleteMutationFunctionWithRef<TData, TParam> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnSuccessFunctionWithRef<TData, TParam>? onSuccess,
  OnErrorFunctionWithRef<TData, TParam>? onError,
  OnMutateFunctionWithRef<TData, TParam>? onMutate,
}) => NotifierProvider.autoDispose.family<MutationNotifierFamilyAutoDispose<TData, TParam, TParam>, MutationState<TData>, TParam>(
    () => MutationNotifierFamilyAutoDispose<TData, TParam, TParam>(
      mutationFunction: mutationFn,
      options: MutationOptions(
        retry: retry ?? 0,
        retryDelay: retryDelay ?? const Duration(seconds: 1),
        onSuccess: onSuccess,
        onError: onError,
        onMutate: (ref,variables) => onMutate?.call(ref,variables)??Future<void>.value(),
      ),
    ),
    name: name,
  );

/// Auto-dispose update mutation provider
AutoDisposeNotifierProviderFamily<UpdateMutationNotifierFamilyAutoDispose<TData, TVariables, TParam>, MutationState<TData>, TParam> updateProviderAutoDispose<TData, TVariables, TParam>({
  required String name,
  required UpdateMutationFunctionWithRef<TData, TVariables, TParam> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnUpdateSuccessFunctionWithRef<TData, TVariables, TParam>? onSuccess,
  OnUpdateErrorFunctionWithRef<TData, TVariables, TParam>? onError,
  OnUpdateMutateFunctionWithRef<TData, TVariables, TParam>? onMutate,
}) => NotifierProvider.autoDispose.family<UpdateMutationNotifierFamilyAutoDispose<TData, TVariables, TParam>, MutationState<TData>, TParam>(
    () => UpdateMutationNotifierFamilyAutoDispose<TData, TVariables, TParam>(
      mutationFunction: mutationFn,
      options: UpdateMutationOptions(
        retry: retry ?? 0,
        retryDelay: retryDelay ?? const Duration(seconds: 1),
        onSuccess: onSuccess,
        onError: onError,
        onMutate: (ref, variables, param) => onMutate?.call(ref, variables, param)??Future<void>.value(),
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
extension MutationProviderExtension<TData, TVariables> on NotifierProvider<MutationNotifier<TData, TVariables>, MutationState<TData>> {
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

/// Extension to create a mutation result from a family provider
extension MutationProviderFamilyExtension<TData, TVariables, TParam> on NotifierProviderFamily<MutationNotifierFamily<TData, TVariables, TParam>, MutationState<TData>, TParam> {
  /// Create a mutation result that can be used in widgets
  MutationResult<TData, TVariables> use(WidgetRef ref, TParam param) {
    final notifier = ref.read(this(param).notifier);
    final state = ref.watch(this(param));

    return MutationResult<TData, TVariables>(
      state: state,
      mutate: notifier.mutate,
      reset: notifier.reset,
    );
  }
}

/// Extension to create a mutation result from an auto-dispose family provider
extension MutationProviderFamilyAutoDisposeExtension<TData, TVariables, TParam> on AutoDisposeNotifierProviderFamily<MutationNotifierFamilyAutoDispose<TData, TVariables, TParam>, MutationState<TData>, TParam> {
  /// Create a mutation result that can be used in widgets
  MutationResult<TData, TVariables> use(WidgetRef ref, TParam param) {
    final notifier = ref.read(this(param).notifier);
    final state = ref.watch(this(param));

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

/// 📚 COMPLETE EXAMPLE: Using MutationProviderFamily
/// 
/// This example shows how to use mutationProviderFamily for a complete
/// Post management system with Create, Update, and Delete operations.
/// 
/// ```dart
/// // 1. Define your data models
/// class Post {
///   final int id;
///   final String title;
///   final String body;
///   final int userId;
/// 
///   const Post({
///     required this.id,
///     required this.title,
///     required this.body,
///     required this.userId,
///   });
/// 
///   Post copyWith({String? title, String? body}) => Post(
///     id: id,
///     title: title ?? this.title,
///     body: body ?? this.body,
///     userId: userId,
///   );
/// }
/// 
/// class CreatePostRequest {
///   final String title;
///   final String body;
///   final int userId;
/// 
///   const CreatePostRequest({
///     required this.title,
///     required this.body,
///     required this.userId,
///   });
/// }
/// 
/// class UpdatePostRequest {
///   final String? title;
///   final String? body;
/// 
///   const UpdatePostRequest({this.title, this.body});
/// }
/// 
/// // 2. Create your API service
/// class ApiService {
///   static Future<Post> createPost(CreatePostRequest request) async {
///     // Simulate API call
///     await Future.delayed(Duration(seconds: 1));
///     return Post(
///       id: DateTime.now().millisecondsSinceEpoch,
///       title: request.title,
///       body: request.body,
///       userId: request.userId,
///     );
///   }
/// 
///   static Future<Post> updatePost(int postId, UpdatePostRequest request) async {
///     // Simulate API call
///     await Future.delayed(Duration(seconds: 1));
///     // In real app, you'd fetch current post and update it
///     return Post(
///       id: postId,
///       title: request.title ?? 'Updated Title',
///       body: request.body ?? 'Updated Body',
///       userId: 1,
///     );
///   }
/// 
///   static Future<void> deletePost(int postId) async {
///     // Simulate API call
///     await Future.delayed(Duration(seconds: 1));
///     // In real app, you'd make DELETE request
///   }
/// }
/// 
/// // 3. Create your mutation providers
/// 
/// // Create post mutation (no family needed - same for all)
/// final createPostProvider = createProvider<Post, CreatePostRequest>(
///   name: 'create-post',
///   mutationFn: (ref, request) => ApiService.createPost(request),
///   onSuccess: (ref, post, request) {
///     // Invalidate posts query to refresh the list
///     // ref.invalidate(postsQueryProvider);
///     print('Post created: ${post.title}');
///   },
///   onError: (ref, request, error, stackTrace) {
///     print('Failed to create post: $error');
///   },
/// );
/// 
/// // Update post mutation (family - different for each post)
/// final updatePostProvider = mutationProviderFamily<Post, UpdatePostRequest, int>(
///   name: 'update-post',
///   mutationFn: (ref, request) {
///     // Access the post ID from the family parameter
///     final postId = ref.read(updatePostProvider(postId).notifier).param;
///     return ApiService.updatePost(postId, request);
///   },
///   onSuccess: (ref, updatedPost, request) {
///     // Invalidate specific post query and posts list
///     // ref.invalidate(postQueryProvider(updatedPost.id));
///     // ref.invalidate(postsQueryProvider);
///     print('Post updated: ${updatedPost.title}');
///   },
///   onError: (ref, request, error, stackTrace) {
///     print('Failed to update post: $error');
///   },
///   onMutate: (ref, request) async {
///     // Optimistic update
///     print('Starting optimistic update...');
///   },
/// );
/// 
/// // Delete post mutation (auto-dispose family - temporary)
/// final deletePostProvider = mutationProviderFamilyAutoDispose<void, void, int>(
///   name: 'delete-post',
///   mutationFn: (ref, _) {
///     // Access the post ID from the family parameter
///     final postId = ref.read(deletePostProvider(postId).notifier).param;
///     return ApiService.deletePost(postId);
///   },
///   onSuccess: (ref, _, __) {
///     // Invalidate posts query to refresh the list
///     // ref.invalidate(postsQueryProvider);
///     print('Post deleted successfully');
///   },
///   onError: (ref, _, error, stackTrace) {
///     print('Failed to delete post: $error');
///   },
/// );
/// 
/// // 4. Use in your widgets
/// 
/// class PostWidget extends ConsumerWidget {
///   final Post post;
/// 
///   const PostWidget({required this.post});
/// 
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     // Method 1: Using extension methods (recommended)
///     final updateMutation = updatePostProvider.use(ref, post.id);
///     final deleteMutation = deletePostProvider.use(ref, post.id);
/// 
///     return Card(
///       child: Column(
///         children: [
///           Text(post.title),
///           Text(post.body),
///           
///           Row(
///             children: [
///               // Update button
///               ElevatedButton(
///                 onPressed: updateMutation.isLoading ? null : () async {
///                   try {
///                     await updateMutation.mutate(UpdatePostRequest(
///                       title: '${post.title} (Updated)',
///                     ));
///                   } catch (e) {
///                     // Handle error (already handled in onError callback)
///                   }
///                 },
///                 child: updateMutation.isLoading
///                     ? SizedBox(
///                         width: 20,
///                         height: 20,
///                         child: CircularProgressIndicator(strokeWidth: 2),
///                       )
///                     : Text('Update'),
///               ),
///               
///               SizedBox(width: 8),
///               
///               // Delete button
///               ElevatedButton(
///                 onPressed: deleteMutation.isLoading ? null : () async {
///                   final confirmed = await showDialog<bool>(
///                     context: context,
///                     builder: (context) => AlertDialog(
///                       title: Text('Delete Post'),
///                       content: Text('Are you sure you want to delete this post?'),
///                       actions: [
///                         TextButton(
///                           onPressed: () => Navigator.pop(context, false),
///                           child: Text('Cancel'),
///                         ),
///                         TextButton(
///                           onPressed: () => Navigator.pop(context, true),
///                           child: Text('Delete'),
///                         ),
///                       ],
///                     ),
///                   );
///                   
///                   if (confirmed == true) {
///                     try {
///                       await deleteMutation.mutate(null);
///                     } catch (e) {
///                       // Handle error
///                     }
///                   }
///                 },
///                 style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
///                 child: deleteMutation.isLoading
///                     ? SizedBox(
///                         width: 20,
///                         height: 20,
///                         child: CircularProgressIndicator(strokeWidth: 2),
///                       )
///                     : Text('Delete'),
///               ),
///             ],
///           ),
///           
///           // Show mutation states
///           if (updateMutation.hasError)
///             Text('Update Error: ${updateMutation.error}', 
///                  style: TextStyle(color: Colors.red)),
///           if (deleteMutation.hasError)
///             Text('Delete Error: ${deleteMutation.error}', 
///                  style: TextStyle(color: Colors.red)),
///         ],
///       ),
///     );
///   }
/// }
/// 
/// // Method 2: Direct provider usage
/// class PostWidgetDirect extends ConsumerWidget {
///   final Post post;
/// 
///   const PostWidgetDirect({required this.post});
/// 
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     // Watch the mutation states directly
///     final updateState = ref.watch(updatePostProvider(post.id));
///     final deleteState = ref.watch(deletePostProvider(post.id));
///     
///     // Get notifiers for triggering mutations
///     final updateNotifier = ref.read(updatePostProvider(post.id).notifier);
///     final deleteNotifier = ref.read(deletePostProvider(post.id).notifier);
/// 
///     return Card(
///       child: Column(
///         children: [
///           Text(post.title),
///           
///           // Update button with state handling
///           updateState.when(
///             idle: () => ElevatedButton(
///               onPressed: () => updateNotifier.mutate(UpdatePostRequest(
///                 title: '${post.title} (Updated)',
///               )),
///               child: Text('Update'),
///             ),
///             loading: () => ElevatedButton(
///               onPressed: null,
///               child: CircularProgressIndicator(),
///             ),
///             success: (updatedPost) => ElevatedButton(
///               onPressed: () => updateNotifier.reset(),
///               child: Text('Updated: ${updatedPost.title}'),
///             ),
///             error: (error, stackTrace) => Column(
///               children: [
///                 Text('Error: $error', style: TextStyle(color: Colors.red)),
///                 ElevatedButton(
///                   onPressed: () => updateNotifier.reset(),
///                   child: Text('Retry'),
///                 ),
///               ],
///             ),
///           ),
///         ],
///       ),
///     );
///   }
/// }
/// 
/// // 5. Create posts screen
/// class CreatePostScreen extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final createMutation = createPostProvider.use(ref);
///     final titleController = TextEditingController();
///     final bodyController = TextEditingController();
/// 
///     return Scaffold(
///       appBar: AppBar(title: Text('Create Post')),
///       body: Padding(
///         padding: EdgeInsets.all(16),
///         child: Column(
///           children: [
///             TextField(
///               controller: titleController,
///               decoration: InputDecoration(labelText: 'Title'),
///             ),
///             TextField(
///               controller: bodyController,
///               decoration: InputDecoration(labelText: 'Body'),
///               maxLines: 3,
///             ),
///             SizedBox(height: 16),
///             
///             ElevatedButton(
///               onPressed: createMutation.isLoading ? null : () async {
///                 try {
///                   await createMutation.mutate(CreatePostRequest(
///                     title: titleController.text,
///                     body: bodyController.text,
///                     userId: 1,
///                   ));
///                   
///                   // Success - navigate back
///                   Navigator.pop(context);
///                 } catch (e) {
///                   // Error handled in onError callback
///                 }
///               },
///               child: createMutation.isLoading
///                   ? CircularProgressIndicator()
///                   : Text('Create Post'),
///             ),
///             
///             if (createMutation.hasError)
///               Text('Error: ${createMutation.error}',
///                    style: TextStyle(color: Colors.red)),
///           ],
///         ),
///       ),
///     );
///   }
/// }
/// ```
/// 
/// ## Key Benefits of MutationProviderFamily:
/// 
/// ✅ **Parameter Support**: Each family instance gets its own parameter (like post ID)
/// ✅ **Type Safety**: Full generic type support for data, variables, and parameters  
/// ✅ **Auto-Dispose**: Memory efficient cleanup with auto-dispose variants
/// ✅ **Extension Methods**: Clean `.use(ref, param)` syntax
/// ✅ **State Management**: Complete mutation state tracking (idle, loading, success, error)
/// ✅ **Optimistic Updates**: `onMutate` callback for immediate UI updates
/// ✅ **Error Handling**: Retry logic and error callbacks
/// ✅ **Integration**: Works seamlessly with query providers for cache invalidation
/// 
/// ## When to Use:
/// 
/// - **mutationProviderFamily**: For operations that need parameters (update/delete specific items)
/// - **mutationProviderFamilyAutoDispose**: For temporary mutations that should clean up
/// - **createProvider**: For simple operations without parameters (create new items)
/// 
/// This pattern provides a clean, scalable way to handle all your mutation needs!
///
