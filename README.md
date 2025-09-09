# Query Provider

A React Query-like data fetching library for Flutter using Riverpod. This library provides powerful data synchronization for Flutter applications with features like caching, background updates, optimistic updates, and more.

## Features

- 🚀 **Declarative Data Fetching**: Simple and intuitive API for fetching data
- 💾 **Intelligent Caching**: Automatic caching with configurable stale time and cache time
- 🔄 **Background Updates**: Automatic refetching when data becomes stale
- ⚡ **Optimistic Updates**: Update UI optimistically before server confirms changes
- 🔁 **Retry Logic**: Built-in retry mechanism with configurable attempts and delays
- 📄 **Pagination Support**: Infinite queries for paginated data
- 🎯 **Mutations**: Handle POST, PUT, DELETE operations with automatic cache updates
- 🔧 **Flexible Configuration**: Extensive customization options
- 🎨 **Type Safe**: Full TypeScript-like type safety with Dart generics
- 🏗️ **Riverpod Integration**: Built on top of Riverpod for excellent state management

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  query_provider: ^1.0.0
  flutter_riverpod: ^2.4.9
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Wrap your app with ProviderScope

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
```

### 2. Create a Query Provider

```dart
import 'package:query_provider/query_provider.dart';

// Define your data fetching function
Future<List<User>> fetchUsers() async {
  final response = await http.get(Uri.parse('https://api.example.com/users'));
  final List<dynamic> data = json.decode(response.body);
  return data.map((json) => User.fromJson(json)).toList();
}

// Create a simple query provider
final usersQueryProvider = queryProvider<List<User>>(
  name: 'users',
  queryFn: fetchUsers,
  options: const QueryOptions<List<User>>(
    staleTime: Duration(minutes: 5),
    cacheTime: Duration(minutes: 10),
  ),
);
```

### 2.1. Parameterized Queries

For queries that depend on parameters, you have several options:

```dart
// Option 1: Function-based approach (simple)
StateNotifierProvider<QueryNotifier<User>, QueryState<User>> userProvider(int userId) {
  return queryProvider<User>(
    name: 'user-$userId',
    queryFn: () => fetchUser(userId),
  );
}

// Option 2: Provider Family (recommended for dynamic parameters)
final userProviderFamily = queryProviderFamily<User, int>(
  name: 'user',
  queryFn: fetchUser, // fetchUser(int userId) function
);

// Option 3: Fixed parameters approach
StateNotifierProvider<QueryNotifier<User>, QueryState<User>> specificUserProvider() {
  return queryProviderWithParams<User, int>(
    name: 'user',
    params: 123, // Fixed user ID
    queryFn: fetchUser,
  );
}

// Usage in widgets:
class UserWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Using Option 1
    final userState1 = ref.watch(userProvider(123));
    
    // Using Option 2 (Provider Family)
    final userState2 = ref.watch(userProviderFamily(123));
    
    // Using Option 3
    final userState3 = ref.watch(specificUserProvider());
    
    return userState1.when(/* ... */);
  }
}
```

### 3. Use the Query in Your Widget

```dart
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersState = ref.watch(usersQueryProvider);

    return usersState.when(
      idle: () => const Text('Ready to load'),
      loading: () => const CircularProgressIndicator(),
      success: (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            title: Text(user.name),
            subtitle: Text(user.email),
          );
        },
      ),
      error: (error, stackTrace) => Text('Error: $error'),
      refetching: (users) => Stack(
        children: [
          ListView.builder(/* ... */),
          const Positioned(
            top: 16,
            right: 16,
            child: CircularProgressIndicator(),
          ),
        ],
      ),
    );
  }
}
```

## Core Concepts

### Query States

Queries can be in one of several states:

- **Idle**: Initial state before any query is executed
- **Loading**: Query is loading for the first time
- **Success**: Query has successfully loaded data
- **Error**: Query has failed with an error
- **Refetching**: Query is refetching (has previous data but loading new data)

### Query Options

Configure query behavior with `QueryOptions`:

```dart
const QueryOptions<User>(
  staleTime: Duration(minutes: 5),      // Data is fresh for 5 minutes
  cacheTime: Duration(minutes: 30),     // Keep in cache for 30 minutes
  refetchOnMount: true,                 // Refetch when component mounts
  refetchOnWindowFocus: false,          // Don't refetch on window focus
  refetchInterval: Duration(seconds: 30), // Auto-refetch every 30 seconds
  retry: 3,                             // Retry 3 times on failure
  retryDelay: Duration(seconds: 1),     // Wait 1 second between retries
  enabled: true,                        // Query is enabled
  keepPreviousData: false,              // Don't keep previous data while loading
  onSuccess: (data) => print('Success: $data'),
  onError: (error, stackTrace) => print('Error: $error'),
)
```

## Mutations

Handle data modifications with mutations:

```dart
// Create a mutation provider
final createUserMutationProvider = MutationProvider<User, Map<String, dynamic>>(
  name: 'create-user',
  mutationFn: (userData) async {
    final response = await http.post(
      Uri.parse('https://api.example.com/users'),
      body: json.encode(userData),
      headers: {'Content-Type': 'application/json'},
    );
    return User.fromJson(json.decode(response.body));
  },
  options: MutationOptions<User, Map<String, dynamic>>(
    onSuccess: (user, variables) {
      print('User created: ${user.name}');
      // Invalidate users query to refetch the list
      ref.read(queryClientProvider).invalidateQueries('users');
    },
    onError: (error, variables, stackTrace) {
      print('Failed to create user: $error');
    },
  ),
);

// Use the mutation in a widget
class CreateUserForm extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createUserMutation = createUserMutationProvider.use(ref);

    return ElevatedButton(
      onPressed: createUserMutation.isLoading
          ? null
          : () async {
              try {
                await createUserMutation.mutate({
                  'name': 'John Doe',
                  'email': 'john@example.com',
                });
                // Success! The onSuccess callback will handle cache invalidation
              } catch (e) {
                // Error handled by onError callback
              }
            },
      child: createUserMutation.isLoading
          ? const CircularProgressIndicator()
          : const Text('Create User'),
    );
  }
}
```

## Infinite Queries

Handle paginated data with infinite queries:

```dart
// Create an infinite query provider
final postsInfiniteQueryProvider = InfiniteQueryProvider<PostPage, int>(
  name: 'posts-infinite',
  queryFn: (pageParam) => fetchPosts(page: pageParam),
  initialPageParam: 1,
  options: InfiniteQueryOptions<PostPage, int>(
    getNextPageParam: (lastPage, allPages) {
      return lastPage.hasMore ? lastPage.page + 1 : null;
    },
    staleTime: const Duration(minutes: 2),
  ),
);

// Use in a widget
class PostsList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infiniteQuery = postsInfiniteQueryProvider.use(ref);

    return infiniteQuery.state.when(
      loading: () => const CircularProgressIndicator(),
      success: (pages, hasNextPage, _, __) {
        final allPosts = pages.expand((page) => page.posts).toList();
        
        return ListView.builder(
          itemCount: allPosts.length + (hasNextPage ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == allPosts.length) {
              return ElevatedButton(
                onPressed: infiniteQuery.fetchNextPage,
                child: const Text('Load More'),
              );
            }
            return PostTile(post: allPosts[index]);
          },
        );
      },
      error: (error, _) => Text('Error: $error'),
      // ... other states
    );
  }
}
```

## Advanced Usage

### Query Client

Access the query client for global operations:

```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryClient = ref.read(queryClientProvider);

    return ElevatedButton(
      onPressed: () {
        // Invalidate all user-related queries
        queryClient.invalidateQueries('user');
        
        // Invalidate all queries
        queryClient.invalidateAll();
        
        // Remove specific queries from cache
        queryClient.removeQueries('user-1');
      },
      child: const Text('Refresh Data'),
    );
  }
}
```

### Custom Hooks

Create reusable query patterns:

```dart
class QueryUtils {
  static QueryProvider<T> createQuery<T>({
    required String key,
    required Future<T> Function() fetcher,
    QueryOptions<T> options = const QueryOptions(),
  }) {
    return QueryProvider<T>(
      name: key,
      queryFn: fetcher,
      options: options,
    );
  }
}

// Usage
final userQuery = QueryUtils.createQuery<User>(
  key: 'user-123',
  fetcher: () => fetchUser(123),
  options: const QueryOptions(staleTime: Duration(minutes: 5)),
);
```

### Error Handling

Handle errors gracefully:

```dart
final userState = ref.watch(userQueryProvider);

return userState.when(
  // ... other states
  error: (error, stackTrace) {
    if (error is NetworkException) {
      return const Text('Network error. Please check your connection.');
    } else if (error is AuthException) {
      return const Text('Authentication failed. Please log in again.');
    } else {
      return Text('An unexpected error occurred: $error');
    }
  },
);
```

## Best Practices

### 1. Query Key Naming

Use descriptive and hierarchical query keys:

```dart
// Good
final userQueryProvider = QueryProvider<User>(name: 'user-$userId', ...);
final userPostsProvider = QueryProvider<List<Post>>(name: 'user-$userId-posts', ...);

// Avoid
final queryProvider = QueryProvider<User>(name: 'query1', ...);
```

### 2. Cache Configuration

Configure cache times based on data volatility:

```dart
// Frequently changing data
const QueryOptions(
  staleTime: Duration(seconds: 30),
  cacheTime: Duration(minutes: 5),
)

// Rarely changing data
const QueryOptions(
  staleTime: Duration(hours: 1),
  cacheTime: Duration(hours: 24),
)
```

### 3. Optimistic Updates

Use mutations with optimistic updates for better UX:

```dart
final updateUserMutation = MutationProvider<User, Map<String, dynamic>>(
  name: 'update-user',
  mutationFn: updateUser,
  options: MutationOptions(
    onMutate: (variables) async {
      // Cancel any outgoing refetches
      final queryClient = ref.read(queryClientProvider);
      
      // Snapshot the previous value
      final previousUser = queryClient.getQueryData(userQueryProvider);
      
      // Optimistically update to the new value
      queryClient.setQueryData(userQueryProvider, User.fromJson(variables));
      
      // Return a context object with the snapshotted value
      return previousUser;
    },
    onError: (error, variables, context) {
      // If the mutation fails, use the context returned from onMutate to roll back
      if (context != null) {
        queryClient.setQueryData(userQueryProvider, context);
      }
    },
    onSuccess: (data, variables) {
      // Invalidate and refetch
      queryClient.invalidateQueries('user');
    },
  ),
);
```

## API Reference

### QueryProvider

```dart
QueryProvider<T>({
  required String name,
  required QueryFunction<T> queryFn,
  QueryOptions<T> options = const QueryOptions(),
})
```

### MutationProvider

```dart
MutationProvider<TData, TVariables>({
  required String name,
  required MutationFunction<TData, TVariables> mutationFn,
  MutationOptions<TData, TVariables> options = const MutationOptions(),
})
```

### InfiniteQueryProvider

```dart
InfiniteQueryProvider<T, TPageParam>({
  required String name,
  required InfiniteQueryFunction<T, TPageParam> queryFn,
  required TPageParam initialPageParam,
  required InfiniteQueryOptions<T, TPageParam> options,
})
```

## Examples

Check out the [example](./example) directory for a complete sample application demonstrating:

- Basic queries with loading states
- Mutations with optimistic updates
- Infinite queries for pagination
- Error handling and retry logic
- Cache invalidation patterns

## Contributing

Contributions are welcome! Please read our [contributing guide](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Inspired by [TanStack Query (React Query)](https://tanstack.com/query)
- Built on top of [Riverpod](https://riverpod.dev/) for state management
- Thanks to the Flutter community for feedback and contributions
