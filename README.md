# QueryProvider - React Query for Flutter/Riverpod

A powerful data fetching and caching library for Flutter applications built on top of Riverpod, inspired by TanStack Query (React Query). QueryProvider solves common data management challenges in Flutter apps by providing intelligent caching, background updates, optimistic updates, and seamless state synchronization.

## 📋 Table of Contents

- [The Problem](#-the-problem)
- [The Solution](#-the-solution)
- [Key Features](#-key-features)
- [Installation](#-installation)
- [Quick Start](#-quick-start)
- [Core Concepts](#-core-concepts)
- [API Reference](#-api-reference)
- [Advanced Usage](#-advanced-usage)
- [Comparison](#-comparison)
- [Migration Guide](#-migration-guide)

## 🚨 The Problem

When building Flutter applications with traditional Riverpod providers, developers face several recurring challenges:

### 1. **Manual Cache Management**
```dart
// ❌ Traditional approach - no caching, refetches every time
final usersProvider = FutureProvider<List<User>>((ref) async {
  return ApiService.fetchUsers(); // Always hits the network
});
```

### 2. **No Background Updates**
```dart
// ❌ Data becomes stale, no automatic refresh
final userProvider = FutureProvider.family<User, int>((ref, id) async {
  return ApiService.fetchUser(id); // Stale data, no refresh mechanism
});
```

### 3. **Complex Loading States**
```dart
// ❌ Manual loading state management
class UserNotifier extends StateNotifier<AsyncValue<User>> {
  UserNotifier() : super(const AsyncValue.loading());
  
  Future<void> fetchUser() async {
    state = const AsyncValue.loading(); // Manual loading state
    try {
      final user = await ApiService.fetchUser();
      state = AsyncValue.data(user);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace); // Manual error handling
    }
  }
}
```

### 4. **No Optimistic Updates**
```dart
// ❌ No way to update UI optimistically
final updateUserProvider = FutureProvider.family<User, UpdateUserRequest>((ref, request) async {
  return ApiService.updateUser(request); // UI waits for server response
});
```

### 5. **Memory Leaks & Resource Management**
```dart
// ❌ Manual cleanup, potential memory leaks
class DataNotifier extends StateNotifier<List<Data>> {
  Timer? _timer;
  
  @override
  void dispose() {
    _timer?.cancel(); // Easy to forget cleanup
    super.dispose();
  }
}
```

### 6. **No Retry Logic**
```dart
// ❌ No automatic retry on failure
final dataProvider = FutureProvider<Data>((ref) async {
  try {
    return await ApiService.fetchData();
  } catch (e) {
    // Fails permanently, no retry
    rethrow;
  }
});
```

### 7. **Duplicated Network Requests**
```dart
// ❌ Multiple widgets cause multiple requests
Widget build(BuildContext context, WidgetRef ref) {
  final users = ref.watch(usersProvider); // Request #1
  final moreUsers = ref.watch(usersProvider); // Request #2 (duplicate!)
  // ...
}
```

## 🚀 The Solution

QueryProvider addresses all these problems with a React Query-inspired approach:

### ✅ **Intelligent Caching**
```dart
final usersProvider = asyncQueryProvider<List<User>>(
  name: 'users',
  queryFn: (ref) => ApiService.fetchUsers(),
  options: QueryOptions(
    staleTime: Duration(minutes: 5), // Fresh for 5 minutes
    cacheTime: Duration(minutes: 30), // Cached for 30 minutes
  ),
);
```

### ✅ **Automatic Background Updates**
```dart
final userProvider = asyncQueryProviderFamily<User, int>(
  name: 'user',
  queryFn: (ref, userId) => ApiService.fetchUser(userId),
  options: QueryOptions(
    refetchOnWindowFocus: true, // Refetch when window gains focus
    refetchOnAppFocus: true, // Refetch when app comes to foreground
    refetchInterval: Duration(minutes: 10), // Periodic updates
  ),
);
```

### ✅ **Built-in Loading & Error States**
```dart
Widget build(BuildContext context, WidgetRef ref) {
  final usersAsync = ref.watch(usersProvider);
  
  return usersAsync.when(
    loading: () => CircularProgressIndicator(),
    error: (error, stack) => ErrorWidget(error),
    data: (users) => UsersList(users),
  );
}
```

### ✅ **Optimistic Updates with Rollback**
```dart
final updateUserMutation = mutationProvider<User, UpdateUserRequest>(
  name: 'update-user',
  mutationFn: (ref, request) => ApiService.updateUser(request),
  onMutate: (ref, request) async {
    final queryClient = ref.read(queryClientProvider);
    
    // Optimistic update
    final currentUser = queryClient.getQueryData<User>('user-${request.id}');
    queryClient.setQueryData('user-${request.id}', request.toUser());
    
    return currentUser; // Return for rollback
  },
  onError: (ref, request, error, stackTrace) async {
    final queryClient = ref.read(queryClientProvider);
    // Rollback on error
    queryClient.invalidateQueries('user-${request.id}');
  },
);
```

### ✅ **Automatic Resource Management**
```dart
// ✅ Automatic cleanup - no memory leaks
final dataProvider = asyncQueryProvider<Data>(
  name: 'data',
  queryFn: (ref) => ApiService.fetchData(),
  options: QueryOptions(
    refetchInterval: Duration(seconds: 30), // Automatically cleaned up
  ),
);
```

### ✅ **Smart Retry Logic**
```dart
final dataProvider = asyncQueryProvider<Data>(
  name: 'data',
  queryFn: (ref) => ApiService.fetchData(),
  options: QueryOptions(
    retry: 3, // Retry 3 times
    retryDelay: Duration(seconds: 2), // Wait 2 seconds between retries
  ),
);
```

### ✅ **Request Deduplication**
```dart
// ✅ Multiple widgets, single request
Widget build(BuildContext context, WidgetRef ref) {
  final users1 = ref.watch(usersProvider); // Request once
  final users2 = ref.watch(usersProvider); // Uses cache
  // Only one network request!
}
```

## 🎯 Key Features

| Feature | Traditional Riverpod | QueryProvider |
|---------|---------------------|---------------|
| **Caching** | Manual | ✅ Automatic with `staleTime`/`cacheTime` |
| **Background Updates** | None | ✅ Window focus, app focus, intervals |
| **Loading States** | Manual | ✅ Built-in `AsyncValue` handling |
| **Error Handling** | Manual | ✅ Automatic retry with exponential backoff |
| **Optimistic Updates** | Complex | ✅ Simple `onMutate`/`onError` callbacks |
| **Request Deduplication** | None | ✅ Automatic |
| **Memory Management** | Manual | ✅ Automatic cleanup |
| **Offline Support** | None | ✅ Cache-first with stale data |
| **DevTools** | Basic | ✅ Rich query inspection |
| **TypeScript-like DX** | Good | ✅ Excellent with generics |

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  query_provider: ^1.0.0
  flutter_riverpod: ^2.6.1
```

## 🚀 Quick Start

### 1. Setup QueryClient

```dart
// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';

void main() {
  runApp(
    ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### 2. Create Query Providers

```dart
// providers/user_providers.dart
import 'package:query_provider/query_provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';

// Simple query
final usersProvider = asyncQueryProvider<List<User>>(
  name: 'users',
  queryFn: (ref) => ApiService.fetchUsers(),
  options: QueryOptions(
    staleTime: Duration(minutes: 5),
    cacheTime: Duration(minutes: 30),
  ),
);

// Parameterized query
final userProvider = asyncQueryProviderFamily<User, int>(
  name: 'user',
  queryFn: (ref, userId) => ApiService.fetchUser(userId),
  options: QueryOptions(
    staleTime: Duration(minutes: 3),
    refetchOnWindowFocus: true,
  ),
);

// Mutation
final createUserMutation = mutationProvider<User, CreateUserRequest>(
  name: 'create-user',
  mutationFn: (ref, request) => ApiService.createUser(request),
  onSuccess: (ref, user, request) async {
    final queryClient = ref.read(queryClientProvider);
    queryClient.invalidateQueries('users'); // Refresh users list
  },
);
```

### 3. Use in Widgets

```dart
// screens/users_screen.dart
class UsersScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersProvider);
    final createUser = ref.watch(createUserMutation);

    return Scaffold(
      appBar: AppBar(title: Text('Users')),
      body: usersAsync.when(
        loading: () => Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error'),
              ElevatedButton(
                onPressed: () => ref.refresh(usersProvider),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
        data: (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            title: Text(user.name),
            subtitle: Text(user.email),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserDetailScreen(userId: user.id),
                ),
              ),
          );
        },
      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: createUser.isLoading ? null : () async {
          try {
            await ref.read(createUserMutation.notifier).mutate(
              CreateUserRequest(name: 'New User', email: 'user@example.com'),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('User created!')),
            );
          } catch (error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $error')),
            );
          }
        },
        child: createUser.isLoading 
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(Icons.add),
      ),
    );
  }
}
```

## 🧠 Core Concepts

### Query Providers

Query providers handle data fetching with intelligent caching:

```dart
// Basic query
final todosProvider = asyncQueryProvider<List<Todo>>(
  name: 'todos',
  queryFn: (ref) => ApiService.fetchTodos(),
  options: QueryOptions(
    staleTime: Duration(minutes: 5), // Data fresh for 5 minutes
    cacheTime: Duration(minutes: 30), // Keep in cache for 30 minutes
    retry: 3, // Retry failed requests 3 times
    refetchOnWindowFocus: true, // Refetch when window gains focus
  ),
);

// Parameterized query
final todoProvider = asyncQueryProviderFamily<Todo, int>(
  name: 'todo',
  queryFn: (ref, todoId) => ApiService.fetchTodo(todoId),
);
```

### Mutations

Mutations handle data modifications with optimistic updates:

```dart
final updateTodoMutation = mutationProvider<Todo, UpdateTodoRequest>(
  name: 'update-todo',
  mutationFn: (ref, request) => ApiService.updateTodo(request),
  onMutate: (ref, request) async {
    // Optimistic update
    final queryClient = ref.read(queryClientProvider);
    final previousTodo = queryClient.getQueryData<Todo>('todo-${request.id}');
    
    queryClient.setQueryData('todo-${request.id}', request.toTodo());
    
    return previousTodo; // For rollback
  },
  onError: (ref, request, error, stackTrace) async {
    // Rollback on error
    final queryClient = ref.read(queryClientProvider);
    queryClient.invalidateQueries('todo-${request.id}');
  },
  onSuccess: (ref, todo, request) async {
    // Update related queries
    final queryClient = ref.read(queryClientProvider);
    queryClient.invalidateQueries('todos');
  },
);
```

### Query Options

Configure query behavior with `QueryOptions`:

```dart
QueryOptions<T>(
  staleTime: Duration(minutes: 5), // How long data stays fresh
  cacheTime: Duration(minutes: 30), // How long unused data stays cached
  refetchOnMount: true, // Refetch when query mounts
  refetchOnWindowFocus: false, // Refetch on window focus
  refetchOnAppFocus: true, // Refetch when app comes to foreground
  pauseRefetchInBackground: true, // Pause refetching in background
  refetchInterval: Duration(minutes: 1), // Periodic refetching
  retry: 3, // Number of retry attempts
  retryDelay: Duration(seconds: 1), // Delay between retries
  enabled: true, // Whether query is enabled
  keepPreviousData: false, // Keep previous data while fetching new
  onSuccess: (data) => print('Success: $data'),
  onError: (error, stackTrace) => print('Error: $error'),
)
```

## 📚 API Reference

### Query Providers

#### `asyncQueryProvider<T>`
Creates a basic async query provider.

```dart
AsyncNotifierProvider<AsyncQueryNotifier<T>, T> asyncQueryProvider<T>({
  required String name, // Unique identifier for caching
  required QueryFunctionWithRef<T> queryFn, // Function that fetches data
  QueryOptions<T>? options, // Configuration options
})
```

#### `asyncQueryProviderFamily<T, P>`
Creates a parameterized async query provider.

```dart
AsyncNotifierProviderFamily<AsyncQueryNotifierFamily<T, P>, T, P> asyncQueryProviderFamily<T, P>({
  required String name,
  required QueryFunctionWithParamsWithRef<T, P> queryFn,
  QueryOptions<T>? options,
})
```

#### `queryProvider<T>` (StateNotifier-based)
Creates a StateNotifier-based query provider for more control.

```dart
StateNotifierProvider<QueryNotifier<T>, QueryState<T>> queryProvider<T>({
  required String name,
  required QueryFunctionWithRef<T> queryFn,
  QueryOptions<T> options = const QueryOptions(),
})
```

### Mutations

#### `mutationProvider<TData, TVariables>`
Creates a mutation provider.

```dart
StateNotifierProvider<MutationNotifier<TData, TVariables>, MutationState<TData>> createProvider<TData, TVariables>({
  required String name,
  required CreateMutationFunctionWithRef<TData, TVariables> mutationFn,
  int? retry = 0,
  Duration? retryDelay = const Duration(seconds: 1),
  OnSuccessFunctionWithRef<TData, TVariables>? onSuccess,
  OnErrorFunctionWithRef<TData, TVariables>? onError,
  OnMutateFunctionWithRef<TData, TVariables>? onMutate,
})
```

### Query Client

Access the query client for manual cache operations:

```dart
    final queryClient = ref.read(queryClientProvider);

// Get cached data
final users = queryClient.getQueryData<List<User>>('users');

// Set cached data
queryClient.setQueryData('users', newUsers);

// Invalidate queries (triggers refetch)
queryClient.invalidateQueries('users');

// Remove queries from cache
queryClient.removeQueries('users');

// Get query state
final queryState = queryClient.getQueryState('users');
```

## 🔧 Advanced Usage

### Dependent Queries

```dart
final userProvider = asyncQueryProviderFamily<User, int>(
  name: 'user',
  queryFn: (ref, userId) => ApiService.fetchUser(userId),
);

final userPostsProvider = asyncQueryProviderFamily<List<Post>, int>(
  name: 'user-posts',
  queryFn: (ref, userId) async {
    // Wait for user data first
    final user = await ref.watch(userProvider(userId).future);
    return ApiService.fetchUserPosts(user.id);
  },
  options: QueryOptions(
    enabled: true, // Can be dynamic based on user data
  ),
);
```

### Infinite Queries

```dart
final infinitePostsProvider = infiniteQueryProvider<List<Post>, int>(
  name: 'infinite-posts',
  queryFn: (ref, pageParam) => ApiService.fetchPosts(page: pageParam),
  getNextPageParam: (lastPage, allPages) {
    return lastPage.hasMore ? allPages.length + 1 : null;
  },
  options: InfiniteQueryOptions(
    staleTime: Duration(minutes: 5),
  ),
);
```

### Optimistic Updates with Rollback

```dart
final updatePostMutation = mutationProvider<Post, UpdatePostRequest>(
  name: 'update-post',
  mutationFn: (ref, request) => ApiService.updatePost(request),
  onMutate: (ref, request) async {
    final queryClient = ref.read(queryClientProvider);
    
    // Cancel outgoing refetches
    await queryClient.cancelQueries('posts');
    
    // Snapshot previous value
    final previousPosts = queryClient.getQueryData<List<Post>>('posts');
    
    // Optimistically update
    if (previousPosts != null) {
      final updatedPosts = previousPosts.map((post) {
        return post.id == request.id ? request.toPost() : post;
      }).toList();
      queryClient.setQueryData('posts', updatedPosts);
    }
    
    return {'previousPosts': previousPosts};
  },
  onError: (ref, request, error, stackTrace) async {
    final queryClient = ref.read(queryClientProvider);
    final context = error.context as Map<String, dynamic>?;
    
    // Rollback to previous value
    if (context?['previousPosts'] != null) {
      queryClient.setQueryData('posts', context!['previousPosts']);
    }
  },
  onSuccess: (ref, post, request) async {
    final queryClient = ref.read(queryClientProvider);
    queryClient.invalidateQueries('posts');
  },
);
```

### Custom Query Keys

```dart
// Simple key
final userProvider = asyncQueryProvider<User>(
  name: 'user',
  queryFn: (ref) => ApiService.fetchCurrentUser(),
);

// Complex key with parameters
final searchProvider = asyncQueryProviderFamily<List<Post>, SearchParams>(
  name: 'search',
  queryFn: (ref, params) => ApiService.search(params),
);

// Usage
final searchResults = ref.watch(searchProvider(SearchParams(
  query: 'flutter',
  category: 'tech',
  sortBy: 'date',
)));
```

### Error Boundaries

```dart
class QueryErrorBoundary extends ConsumerWidget {
  final Widget child;
  
  const QueryErrorBoundary({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return child;
  }
}

// Usage in widget
Widget build(BuildContext context, WidgetRef ref) {
  final postsAsync = ref.watch(postsProvider);
  
  return postsAsync.when(
    loading: () => LoadingWidget(),
    error: (error, stack) => ErrorBoundary(
      error: error,
      onRetry: () => ref.refresh(postsProvider),
    ),
    data: (posts) => PostsList(posts),
  );
}
```

## ⚖️ Comparison

### QueryProvider vs Traditional Riverpod

| Aspect | Traditional Riverpod | QueryProvider |
|--------|---------------------|---------------|
| **Setup Complexity** | Simple | Moderate |
| **Caching** | Manual | Automatic |
| **Background Updates** | Manual | Automatic |
| **Error Handling** | Manual | Built-in with retry |
| **Loading States** | Manual | Built-in |
| **Optimistic Updates** | Complex | Simple |
| **Memory Management** | Manual | Automatic |
| **DevTools Support** | Basic | Rich |
| **Learning Curve** | Low | Moderate |
| **Bundle Size** | Small | Moderate |

### When to Use QueryProvider

✅ **Use QueryProvider when:**
- Building data-heavy applications
- Need intelligent caching and background updates
- Want optimistic updates with rollback
- Require offline-first behavior
- Building real-time or collaborative apps
- Need comprehensive error handling and retry logic

❌ **Use Traditional Riverpod when:**
- Building simple apps with minimal data fetching
- Bundle size is critical
- Team is not familiar with React Query concepts
- Need maximum control over every aspect of state management

## 📈 Migration Guide

### From FutureProvider

```dart
// Before
final usersProvider = FutureProvider<List<User>>((ref) async {
  return ApiService.fetchUsers();
});

// After
final usersProvider = asyncQueryProvider<List<User>>(
  name: 'users',
  queryFn: (ref) => ApiService.fetchUsers(),
  options: QueryOptions(
    staleTime: Duration(minutes: 5),
    cacheTime: Duration(minutes: 30),
  ),
);
```

### From StateNotifierProvider

```dart
// Before
class UsersNotifier extends StateNotifier<AsyncValue<List<User>>> {
  UsersNotifier() : super(const AsyncValue.loading()) {
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    state = const AsyncValue.loading();
    try {
      final users = await ApiService.fetchUsers();
      state = AsyncValue.data(users);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

final usersProvider = StateNotifierProvider<UsersNotifier, AsyncValue<List<User>>>(
  (ref) => UsersNotifier(),
);

// After
final usersProvider = asyncQueryProvider<List<User>>(
  name: 'users',
  queryFn: (ref) => ApiService.fetchUsers(),
  options: QueryOptions(
    staleTime: Duration(minutes: 5),
    retry: 3,
    refetchOnWindowFocus: true,
  ),
);
```

### From Manual Cache Management

```dart
// Before - Manual caching
class CacheNotifier extends StateNotifier<Map<String, dynamic>> {
  CacheNotifier() : super({});
  
  Future<User> getUser(int id) async {
    final cacheKey = 'user-$id';
    if (state.containsKey(cacheKey)) {
      final entry = state[cacheKey];
      if (DateTime.now().difference(entry['timestamp']).inMinutes < 5) {
        return entry['data'];
      }
    }
    
    final user = await ApiService.fetchUser(id);
    state = {
      ...state,
      cacheKey: {
        'data': user,
        'timestamp': DateTime.now(),
      },
    };
    return user;
  }
}

// After - Automatic caching
final userProvider = asyncQueryProviderFamily<User, int>(
  name: 'user',
  queryFn: (ref, userId) => ApiService.fetchUser(userId),
  options: QueryOptions(
    staleTime: Duration(minutes: 5),
    cacheTime: Duration(minutes: 30),
  ),
);
```

## 🎉 Conclusion

QueryProvider brings the power of React Query to Flutter, solving common data management challenges with:

- **🚀 Zero-config caching** - Works out of the box
- **🔄 Smart background updates** - Keep data fresh automatically  
- **⚡ Optimistic updates** - Instant UI feedback with rollback
- **🛡️ Built-in error handling** - Retry logic and error boundaries
- **🧠 Intelligent request deduplication** - No duplicate network calls
- **💾 Memory efficient** - Automatic cleanup and resource management

Start building better Flutter apps today with QueryProvider!

## 📖 Further Reading

- [API Documentation](./docs/API.md)
- [Examples](./example/)
- [Migration Guide](./docs/MIGRATION.md)
- [Best Practices](./docs/BEST_PRACTICES.md)
- [Troubleshooting](./docs/TROUBLESHOOTING.md)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](./CONTRIBUTING.md) for details.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.