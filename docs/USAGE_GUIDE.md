# Query Provider Usage Guide

This guide provides detailed examples and patterns for using Query Provider effectively in your Flutter applications.

## Table of Contents

1. [Basic Setup](#basic-setup)
2. [Simple Queries](#simple-queries)
3. [Parameterized Queries](#parameterized-queries)
4. [Mutations](#mutations)
5. [Infinite Queries](#infinite-queries)
6. [Error Handling](#error-handling)
7. [Cache Management](#cache-management)
8. [Optimistic Updates](#optimistic-updates)
9. [Advanced Patterns](#advanced-patterns)

## Basic Setup

### 1. App Configuration

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Query Provider App',
      home: const HomeScreen(),
    );
  }
}
```

### 2. API Service Setup

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://jsonplaceholder.typicode.com';

  static Future<List<User>> getUsers() async {
    final response = await http.get(Uri.parse('$baseUrl/users'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load users');
    }
  }

  static Future<User> getUser(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/users/$id'));
    if (response.statusCode == 200) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load user');
    }
  }

  static Future<User> createUser(Map<String, dynamic> userData) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(userData),
    );
    if (response.statusCode == 201) {
      return User.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create user');
    }
  }
}
```

## Simple Queries

### Basic Query Provider

```dart
import 'package:query_provider/query_provider.dart';

// Create a simple query provider
final usersQueryProvider = QueryProvider<List<User>>(
  name: 'users',
  queryFn: ApiService.getUsers,
  options: const QueryOptions<List<User>>(
    staleTime: Duration(minutes: 5),
    cacheTime: Duration(minutes: 10),
    refetchOnMount: true,
  ),
);
```

### Using Query in Widget

```dart
class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersState = ref.watch(usersQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(usersQueryProvider.notifier).refetch(),
          ),
        ],
      ),
      body: usersState.when(
        idle: () => const Center(
          child: Text('Ready to load users'),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        success: (users) => RefreshIndicator(
          onRefresh: () => ref.read(usersQueryProvider.notifier).refetch(),
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user.name),
                subtitle: Text(user.email),
                leading: CircleAvatar(child: Text(user.name[0])),
              );
            },
          ),
        ),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Error: $error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(usersQueryProvider.notifier).refetch(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        refetching: (users) => Stack(
          children: [
            ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return ListTile(
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  leading: CircleAvatar(child: Text(user.name[0])),
                );
              },
            ),
            const Positioned(
              top: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 8),
                      Text('Refreshing...'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Parameterized Queries

### Query with Parameters

```dart
// Create a parameterized query provider
QueryProvider<User> userQueryProvider(int userId) {
  return QueryProvider<User>(
    name: 'user-$userId',
    queryFn: () => ApiService.getUser(userId),
    options: const QueryOptions<User>(
      staleTime: Duration(minutes: 3),
      cacheTime: Duration(minutes: 15),
    ),
  );
}

// Use in widget
class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userQueryProvider(userId));

    return Scaffold(
      appBar: AppBar(title: const Text('User Details')),
      body: userState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        success: (user) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${user.name}', style: const TextStyle(fontSize: 18)),
              Text('Email: ${user.email}', style: const TextStyle(fontSize: 16)),
              Text('Phone: ${user.phone}', style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
        error: (error, _) => Center(child: Text('Error: $error')),
        idle: () => const Center(child: Text('Loading...')),
        refetching: (user) => Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${user.name}', style: const TextStyle(fontSize: 18)),
              Text('Email: ${user.email}', style: const TextStyle(fontSize: 16)),
              Text('Phone: ${user.phone}', style: const TextStyle(fontSize: 16)),
              const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
```

## Mutations

### Basic Mutation

```dart
// Create a mutation provider
final createUserMutationProvider = MutationProvider<User, Map<String, dynamic>>(
  name: 'create-user',
  mutationFn: ApiService.createUser,
  options: MutationOptions<User, Map<String, dynamic>>(
    onSuccess: (user, variables) {
      print('User created successfully: ${user.name}');
    },
    onError: (error, variables, stackTrace) {
      print('Failed to create user: $error');
    },
  ),
);

// Use in widget
class CreateUserForm extends ConsumerStatefulWidget {
  const CreateUserForm({super.key});

  @override
  ConsumerState<CreateUserForm> createState() => _CreateUserFormState();
}

class _CreateUserFormState extends ConsumerState<CreateUserForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final createUserMutation = createUserMutationProvider.use(ref);

    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter an email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: createUserMutation.isLoading
                ? null
                : () async {
                    if (_formKey.currentState!.validate()) {
                      try {
                        await createUserMutation.mutate({
                          'name': _nameController.text,
                          'email': _emailController.text,
                        });
                        
                        // Clear form on success
                        _nameController.clear();
                        _emailController.clear();
                        
                        // Show success message
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('User created successfully!')),
                          );
                        }
                      } catch (e) {
                        // Error is handled by the mutation's onError callback
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    }
                  },
            child: createUserMutation.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create User'),
          ),
          if (createUserMutation.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Error: ${createUserMutation.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}
```

## Infinite Queries

### Paginated Data

```dart
// Define page data structure
class PostPage {
  final List<Post> posts;
  final int page;
  final bool hasMore;

  const PostPage({
    required this.posts,
    required this.page,
    required this.hasMore,
  });
}

// API service for paginated data
class PostService {
  static Future<PostPage> getPosts({int page = 1, int limit = 10}) async {
    final response = await http.get(
      Uri.parse('https://jsonplaceholder.typicode.com/posts?_page=$page&_limit=$limit'),
    );
    
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      final posts = data.map((json) => Post.fromJson(json)).toList();
      
      return PostPage(
        posts: posts,
        page: page,
        hasMore: posts.length == limit, // Assume more if we got a full page
      );
    } else {
      throw Exception('Failed to load posts');
    }
  }
}

// Create infinite query provider
final postsInfiniteQueryProvider = InfiniteQueryProvider<PostPage, int>(
  name: 'posts-infinite',
  queryFn: (pageParam) => PostService.getPosts(page: pageParam),
  initialPageParam: 1,
  options: InfiniteQueryOptions<PostPage, int>(
    getNextPageParam: (lastPage, allPages) {
      return lastPage.hasMore ? lastPage.page + 1 : null;
    },
    staleTime: const Duration(minutes: 2),
  ),
);

// Use in widget
class PostsListScreen extends ConsumerWidget {
  const PostsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infiniteQuery = postsInfiniteQueryProvider.use(ref);

    return Scaffold(
      appBar: AppBar(title: const Text('Posts')),
      body: infiniteQuery.state.when(
        idle: () => const Center(child: Text('Ready to load')),
        loading: () => const Center(child: CircularProgressIndicator()),
        success: (pages, hasNextPage, _, __) {
          final allPosts = pages.expand((page) => page.posts).toList();
          
          return RefreshIndicator(
            onRefresh: infiniteQuery.refetch,
            child: ListView.builder(
              itemCount: allPosts.length + (hasNextPage ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == allPosts.length) {
                  // Load more button/indicator
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(
                      child: infiniteQuery.isFetchingNextPage
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: infiniteQuery.fetchNextPage,
                              child: const Text('Load More'),
                            ),
                    ),
                  );
                }
                
                final post = allPosts[index];
                return ListTile(
                  title: Text(post.title),
                  subtitle: Text(
                    post.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          );
        },
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $error'),
              ElevatedButton(
                onPressed: infiniteQuery.refetch,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        fetchingNextPage: (pages, hasNextPage, _, __) {
          final allPosts = pages.expand((page) => page.posts).toList();
          
          return ListView.builder(
            itemCount: allPosts.length + 1,
            itemBuilder: (context, index) {
              if (index == allPosts.length) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              
              final post = allPosts[index];
              return ListTile(
                title: Text(post.title),
                subtitle: Text(
                  post.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          );
        },
        fetchingPreviousPage: (pages, _, __, ___) {
          // Handle previous page loading if needed
          final allPosts = pages.expand((page) => page.posts).toList();
          return ListView.builder(
            itemCount: allPosts.length,
            itemBuilder: (context, index) {
              final post = allPosts[index];
              return ListTile(
                title: Text(post.title),
                subtitle: Text(post.body),
              );
            },
          );
        },
      ),
    );
  }
}
```

## Error Handling

### Custom Error Types

```dart
// Define custom error types
abstract class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
}

class NetworkException extends ApiException {
  const NetworkException(super.message);
}

class AuthException extends ApiException {
  const AuthException(super.message);
}

class ValidationException extends ApiException {
  final Map<String, String> errors;
  const ValidationException(super.message, this.errors);
}

// Enhanced API service with proper error handling
class ApiService {
  static Future<T> _handleResponse<T>(
    Future<http.Response> Function() request,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final response = await request();
      
      switch (response.statusCode) {
        case 200:
        case 201:
          return fromJson(json.decode(response.body));
        case 401:
          throw const AuthException('Authentication failed');
        case 422:
          final errorData = json.decode(response.body);
          throw ValidationException(
            'Validation failed',
            Map<String, String>.from(errorData['errors'] ?? {}),
          );
        case 500:
          throw const NetworkException('Server error');
        default:
          throw NetworkException('HTTP ${response.statusCode}: ${response.reasonPhrase}');
      }
    } on SocketException {
      throw const NetworkException('No internet connection');
    } on TimeoutException {
      throw const NetworkException('Request timeout');
    }
  }
}

// Error handling in widgets
class UserListWithErrorHandling extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersState = ref.watch(usersQueryProvider);

    return usersState.when(
      loading: () => const CircularProgressIndicator(),
      success: (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) => UserTile(user: users[index]),
      ),
      error: (error, stackTrace) {
        if (error is NetworkException) {
          return ErrorWidget.network(
            message: error.message,
            onRetry: () => ref.read(usersQueryProvider.notifier).refetch(),
          );
        } else if (error is AuthException) {
          return ErrorWidget.auth(
            message: error.message,
            onLogin: () => Navigator.pushNamed(context, '/login'),
          );
        } else if (error is ValidationException) {
          return ErrorWidget.validation(
            message: error.message,
            errors: error.errors,
          );
        } else {
          return ErrorWidget.generic(
            message: error.toString(),
            onRetry: () => ref.read(usersQueryProvider.notifier).refetch(),
          );
        }
      },
      idle: () => const Text('Ready to load'),
      refetching: (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) => UserTile(user: users[index]),
      ),
    );
  }
}
```

## Cache Management

### Manual Cache Operations

```dart
class CacheManagementExample extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryClient = ref.read(queryClientProvider);

    return Column(
      children: [
        ElevatedButton(
          onPressed: () {
            // Invalidate all user-related queries
            queryClient.invalidateQueries('user');
          },
          child: const Text('Refresh Users'),
        ),
        ElevatedButton(
          onPressed: () {
            // Invalidate specific query
            queryClient.invalidateQueries('user-123');
          },
          child: const Text('Refresh User 123'),
        ),
        ElevatedButton(
          onPressed: () {
            // Remove queries from cache
            queryClient.removeQueries('user');
          },
          child: const Text('Clear User Cache'),
        ),
        ElevatedButton(
          onPressed: () {
            // Invalidate all queries
            queryClient.invalidateAll();
          },
          child: const Text('Refresh All Data'),
        ),
      ],
    );
  }
}
```

## Optimistic Updates

### Mutation with Optimistic Updates

```dart
final updateUserMutationProvider = MutationProvider<User, UpdateUserRequest>(
  name: 'update-user',
  mutationFn: (request) => ApiService.updateUser(request.id, request.data),
  options: MutationOptions<User, UpdateUserRequest>(
    onMutate: (variables) async {
      final queryClient = ref.read(queryClientProvider);
      
      // Cancel any outgoing refetches
      // (so they don't overwrite our optimistic update)
      
      // Snapshot the previous value
      final previousUser = queryClient.getQueryData(userQueryProvider(variables.id));
      
      // Optimistically update to the new value
      final optimisticUser = previousUser?.copyWith(
        name: variables.data['name'],
        email: variables.data['email'],
      );
      
      if (optimisticUser != null) {
        queryClient.setQueryData(userQueryProvider(variables.id), optimisticUser);
      }
      
      // Return a context object with the snapshotted value
      return previousUser;
    },
    onError: (error, variables, context) {
      final queryClient = ref.read(queryClientProvider);
      
      // If the mutation fails, use the context returned from onMutate to roll back
      if (context != null) {
        queryClient.setQueryData(userQueryProvider(variables.id), context);
      }
    },
    onSuccess: (data, variables) {
      final queryClient = ref.read(queryClientProvider);
      
      // Update with the actual server response
      queryClient.setQueryData(userQueryProvider(variables.id), data);
      
      // Invalidate and refetch related queries
      queryClient.invalidateQueries('users');
    },
  ),
);
```

## Advanced Patterns

### Dependent Queries

```dart
// Query that depends on another query's result
class UserPostsScreen extends ConsumerWidget {
  const UserPostsScreen({super.key, required this.userId});

  final int userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userQueryProvider(userId));
    
    return userState.when(
      loading: () => const CircularProgressIndicator(),
      success: (user) {
        // Only fetch posts when user is loaded
        final postsState = ref.watch(userPostsQueryProvider(user.id));
        
        return Column(
          children: [
            UserHeader(user: user),
            Expanded(
              child: postsState.when(
                loading: () => const CircularProgressIndicator(),
                success: (posts) => PostsList(posts: posts),
                error: (error, _) => Text('Error loading posts: $error'),
                idle: () => const Text('Loading posts...'),
                refetching: (posts) => PostsList(posts: posts),
              ),
            ),
          ],
        );
      },
      error: (error, _) => Text('Error loading user: $error'),
      idle: () => const Text('Loading user...'),
      refetching: (user) => Column(
        children: [
          UserHeader(user: user),
          const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
```

### Parallel Queries

```dart
class DashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersState = ref.watch(usersQueryProvider);
    final postsState = ref.watch(postsQueryProvider);
    final commentsState = ref.watch(commentsQueryProvider);

    // All queries run in parallel
    return Column(
      children: [
        _buildSection('Users', usersState),
        _buildSection('Posts', postsState),
        _buildSection('Comments', commentsState),
      ],
    );
  }

  Widget _buildSection<T>(String title, QueryState<T> state) {
    return Card(
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          state.when(
            loading: () => const CircularProgressIndicator(),
            success: (data) => Text('Loaded ${data.toString().length} items'),
            error: (error, _) => Text('Error: $error'),
            idle: () => const Text('Ready'),
            refetching: (data) => const Text('Refreshing...'),
          ),
        ],
      ),
    );
  }
}
```

This usage guide covers the most common patterns and advanced use cases for Query Provider. For more examples, check out the complete example application in the `/example` directory.
