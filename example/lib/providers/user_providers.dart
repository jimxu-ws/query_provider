import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';

/// Query provider for fetching all users (traditional approach)
final usersQueryProvider = queryProvider<List<User>>(
  name: 'users',
  queryFn: ApiService.fetchUsers,
  options: const QueryOptions<List<User>>(
    staleTime: Duration(minutes: 5),
    cacheTime: Duration(minutes: 10),
    refetchOnMount: true,
  ),
);

/// Hook-based users query (use in HookConsumerWidget)
/// 
/// Usage example:
/// ```dart
/// class UsersTab extends HookConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final usersQuery = useUsersQuery(ref);
///     
///     if (usersQuery.isLoading) return CircularProgressIndicator();
///     if (usersQuery.hasError) return Text('Error: ${usersQuery.error}');
///     if (usersQuery.hasData) {
///       return ListView.builder(
///         itemCount: usersQuery.data!.length,
///         itemBuilder: (context, index) => ListTile(
///           title: Text(usersQuery.data![index].name),
///         ),
///       );
///     }
///     return ElevatedButton(
///       onPressed: usersQuery.refetch,
///       child: Text('Load Users'),
///     );
///   }
/// }
/// ```
SmartQueryResult<List<User>> useUsersQuery(WidgetRef ref) {
  return useSmartQuery<List<User>>(
    ref: ref,
    fetchFn: ApiService.fetchUsers,
    cacheKey: 'users',
    staleTime: const Duration(minutes: 5),
    cacheTime: const Duration(minutes: 10),
    enableBackgroundRefresh: true,
    enableWindowFocusRefresh: true,
    cacheErrors: false,
  );
}

/// Hook-based single user query (use in HookConsumerWidget)
/// 
/// Usage example:
/// ```dart
/// class UserDetailWidget extends HookConsumerWidget {
///   final int userId;
///   
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final userQuery = useUserQuery(ref, userId);
///     
///     return userQuery.data != null 
///         ? Text(userQuery.data!.name)
///         : CircularProgressIndicator();
///   }
/// }
/// ```
SmartQueryResult<User> useUserQuery(WidgetRef ref, int userId) {
  return useSmartQuery<User>(
    ref: ref,
    fetchFn: () => ApiService.fetchUser(userId),
    cacheKey: 'user-$userId',
    staleTime: const Duration(minutes: 3),
    cacheTime: const Duration(minutes: 15),
    enableBackgroundRefresh: true,
    enableWindowFocusRefresh: true,
    cacheErrors: false,
  );
}

/// Query provider for fetching a single user by ID (using function approach)
StateNotifierProvider<QueryNotifier<User>, QueryState<User>> userQueryProvider(int userId) {
  return queryProvider<User>(
    name: 'user-$userId',
    queryFn: () => ApiService.fetchUser(userId),
    options: const QueryOptions<User>(
      staleTime: Duration(minutes: 3),
      cacheTime: Duration(minutes: 15),
    ),
  );
}

/// Query provider family for fetching users by ID (recommended approach)
final userQueryProviderFamily = queryProviderFamily<User, int>(
  name: 'user',
  queryFn: ApiService.fetchUser,
  options: const QueryOptions<User>(
    staleTime: Duration(minutes: 3),
    cacheTime: Duration(minutes: 15),
  ),
);

/// Query provider family for searching users by name
final userSearchProviderFamily = queryProviderFamily<List<User>, String>(
  name: 'userSearch',
  queryFn: ApiService.searchUsers,
  options: const QueryOptions<List<User>>(
    staleTime: Duration(seconds: 30), // Search results get stale quickly
    cacheTime: Duration(minutes: 5),
  ),
);

/// Alternative: Using queryProviderWithParams (with fixed parameters)
StateNotifierProvider<QueryNotifier<User>, QueryState<User>> userQueryWithParams(int userId) {
  return queryProviderWithParams<User, int>(
    name: 'user',
    params: userId,
    queryFn: ApiService.fetchUser,
    options: const QueryOptions<User>(
      staleTime: Duration(minutes: 3),
      cacheTime: Duration(minutes: 15),
    ),
  );
}

/// Mutation provider for creating a new user
final createUserMutationProvider = StateNotifierProvider.family<MutationNotifier<User, Map<String, dynamic>>, MutationState<User>, void>(
  (ref, _) => MutationNotifier<User, Map<String, dynamic>>(
    mutationFn: ApiService.createUser,
    options: MutationOptions<User, Map<String, dynamic>>(
      onMutate: (variables) async {
        final queryClient = ref.read(queryClientProvider);
        
        // Optimistic update: Add the new user to the cache immediately
        final currentUsers = queryClient.getQueryData<List<User>>('users');
        if (currentUsers != null) {
          final newUser = User(
            id: DateTime.now().millisecondsSinceEpoch, // Temporary ID
            name: variables['name'] as String,
            email: variables['email'] as String,
            avatar: variables['avatar'] as String?,
          );
          queryClient.setQueryData<List<User>>('users', [...currentUsers, newUser]);
        }
      },
      onSuccess: (user, variables) async {
        final queryClient = ref.read(queryClientProvider);
        print('User created successfully: ${user.name}');
        
        // Invalidate users query to refetch fresh data from server
        queryClient.invalidateQueries('users');
        
        // Also invalidate user search queries as they might include this new user
        queryClient.invalidateQueries('userSearch');
      },
      onError: (error, variables, stackTrace) async {
        final queryClient = ref.read(queryClientProvider);
        print('Failed to create user: $error');
        
        // Rollback optimistic update by invalidating the cache
        queryClient.invalidateQueries('users');
      },
    ),
  ),
);

/// Mutation provider for updating a user
final updateUserMutationProvider = StateNotifierProvider.family<MutationNotifier<User, Map<String, dynamic>>, MutationState<User>, int>(
  (ref, userId) => MutationNotifier<User, Map<String, dynamic>>(
    mutationFn: (variables) => ApiService.updateUser(userId, variables),
    options: MutationOptions<User, Map<String, dynamic>>(
      onMutate: (variables) async {
        final queryClient = ref.read(queryClientProvider);
        
        // Optimistic update: Update the user in the cache immediately
        final currentUsers = queryClient.getQueryData<List<User>>('users');
        if (currentUsers != null) {
          final updatedUsers = currentUsers.map((user) {
            if (user.id == userId) {
              return User(
                id: user.id,
                name: variables['name'] as String? ?? user.name,
                email: variables['email'] as String? ?? user.email,
                avatar: variables['avatar'] as String? ?? user.avatar,
              );
            }
            return user;
          }).toList();
          queryClient.setQueryData<List<User>>('users', updatedUsers);
        }
        
        // Also update individual user cache
        final currentUser = queryClient.getQueryData<User>('user-$userId');
        if (currentUser != null) {
          final updatedUser = User(
            id: currentUser.id,
            name: variables['name'] as String? ?? currentUser.name,
            email: variables['email'] as String? ?? currentUser.email,
            avatar: variables['avatar'] as String? ?? currentUser.avatar,
          );
          queryClient.setQueryData<User>('user-$userId', updatedUser);
        }
      },
      onSuccess: (user, variables) async {
        final queryClient = ref.read(queryClientProvider);
        print('User updated successfully: ${user.name}');
        
        // Invalidate related queries to ensure fresh data
        queryClient.invalidateQueries('users');
        queryClient.invalidateQueries('user-$userId');
        queryClient.invalidateQueries('userSearch');
      },
      onError: (error, variables, stackTrace) async {
        final queryClient = ref.read(queryClientProvider);
        print('Failed to update user: $error');
        
        // Rollback optimistic updates
        queryClient.invalidateQueries('users');
        queryClient.invalidateQueries('user-$userId');
      },
    ),
  ),
);

/// Mutation provider for deleting a user
final deleteUserMutationProvider = StateNotifierProvider.family<MutationNotifier<void, int>, MutationState<void>, int>(
  (ref, userId) => MutationNotifier<void, int>(
    mutationFn: (id) => ApiService.deleteUser(id),
    options: MutationOptions<void, int>(
      onMutate: (id) async {
        final queryClient = ref.read(queryClientProvider);
        
        // Optimistic update: Remove the user from the cache immediately
        final currentUsers = queryClient.getQueryData<List<User>>('users');
        if (currentUsers != null) {
          final updatedUsers = currentUsers.where((user) => user.id != id).toList();
          queryClient.setQueryData<List<User>>('users', updatedUsers);
        }
        
        // Remove individual user cache entry
        queryClient.removeQueries('user-$id');
      },
      onSuccess: (_, id) async {
        final queryClient = ref.read(queryClientProvider);
        print('User $id deleted successfully');
        
        // Invalidate queries to ensure consistency
        queryClient.invalidateQueries('users');
        queryClient.invalidateQueries('userSearch');
        queryClient.removeQueries('user-$id');
      },
      onError: (error, id, stackTrace) async {
        final queryClient = ref.read(queryClientProvider);
        print('Failed to delete user $id: $error');
        
        // Rollback optimistic update
        queryClient.invalidateQueries('users');
      },
    ),
  ),
);
