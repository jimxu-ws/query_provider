import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';

import '../examples/background_foreground_example.dart';
import '../examples/background_refetch_example.dart';
import '../examples/lifecycle_aware_example.dart';
import '../examples/window_focus_example.dart';
import '../providers/user_providers.dart';
import '../models/user.dart';
import 'user_detail_screen.dart';
import 'posts_screen.dart';
import 'user_search_screen.dart';
import 'provider_comparison_screen.dart';
import 'cache_debug_screen.dart';
import 'smart_cache_examples.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 9,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Query Provider Example'),
          actions: [
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CacheDebugScreen(),
                  ),
                );
              },
              tooltip: 'Cache Debug',
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Users', icon: Icon(Icons.people)),
              Tab(text: 'Posts', icon: Icon(Icons.article)),
              Tab(text: 'Search', icon: Icon(Icons.search)),
              Tab(text: 'Mutations', icon: Icon(Icons.edit)),
              Tab(text: 'BackgroundRefetchExample', icon: Icon(Icons.code)),
              Tab(text: 'BackgroundForegroundExample', icon: Icon(Icons.code)),
              Tab(text: 'LifecycleAwareExample', icon: Icon(Icons.code)),
              Tab(text: 'WindowFocusExample', icon: Icon(Icons.code)),
              Tab(text: 'SmartCacheComparisonExample', icon: Icon(Icons.abc)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            UsersTab(),
            PostsTab(),
            SearchTab(),
            MutationsTab(),
            BackgroundRefetchExample(),
            BackgroundForegroundExample(),
            LifecycleAwareExample(),
            WindowFocusExample(),
            SmartCacheComparisonScreen(),
          ],
        ),
      ),
    );
  }
}

class UsersTab extends ConsumerWidget {
  const UsersTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersState = ref.watch(usersQueryProvider);

    return usersState.when(
      idle: () => const Center(child: Text('Tap to load users')),
      loading: () => const Center(child: CircularProgressIndicator()),
      success: (users) => RefreshIndicator(
        onRefresh: () async {
          await ref.read(usersQueryProvider.notifier).refetch();
        },
        child: Column(
          children: [
            // Comparison button
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProviderComparisonScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Compare Provider Approaches'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            // Users list
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return UserListTile(user: user);
                },
              ),
            ),
          ],
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
              return UserListTile(user: user);
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
    ) ?? const Center(child: Text('Unknown state'));
  }
}

class UserListTile extends ConsumerWidget {
  const UserListTile({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deleteUserMutation = ref.watch(deleteUserMutationProvider(user.id));
    
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.avatar != null ? NetworkImage(user.avatar!) : null,
        child: user.avatar == null ? Text(user.name[0]) : null,
      ),
      title: Text(user.name),
      subtitle: Text(user.email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          switch (deleteUserMutation) {
            MutationIdle<void>() => IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteDialog(context, ref),
            ),
            MutationLoading<void>() => const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            MutationSuccess<void>() => const Icon(Icons.check, color: Colors.green),
            MutationError<void>() => IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteDialog(context, ref),
            ),
          },
          const Icon(Icons.arrow_forward_ios),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserDetailScreen(userId: user.id),
          ),
        );
      },
    );
  }
  
  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(deleteUserMutationProvider(user.id).notifier).mutate(user.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${user.name} deleted successfully!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete ${user.name}: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class PostsTab extends ConsumerWidget {
  const PostsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PostsScreen();
  }
}

class SearchTab extends ConsumerWidget {
  const SearchTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const UserSearchScreen();
  }
}

class MutationsTab extends ConsumerStatefulWidget {
  const MutationsTab({super.key});

  @override
  ConsumerState<MutationsTab> createState() => _MutationsTabState();
}

class _MutationsTabState extends ConsumerState<MutationsTab> {
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
    final createUserMutation = ref.watch(createUserMutationProvider(null));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Create New User',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: createUserMutation.isLoading
                ? null
                : () async {
                    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please fill in all fields')),
                      );
                      return;
                    }

                    try {
                      await ref.read(createUserMutationProvider(null).notifier).mutate({
                        'name': _nameController.text,
                        'email': _emailController.text,
                      });

                      _nameController.clear();
                      _emailController.clear();

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('User created successfully!')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
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
          const SizedBox(height: 24),
          if (createUserMutation.hasError) ...[
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Error',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      createUserMutation.error.toString(),
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (createUserMutation.isSuccess && createUserMutation.data != null) ...[
            Card(
              color: Colors.green[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Success',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Created user: ${createUserMutation.data!.name}',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
