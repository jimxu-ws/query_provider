import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';

import '../examples/background_foreground_example.dart';
import '../examples/background_refetch_example.dart';
import '../examples/lifecycle_aware_example.dart';
import '../examples/window_focus_example.dart';
import '../providers/user_providers.dart';
import 'user_detail_async_screen.dart';
import '../models/user.dart';
import 'user_detail_screen.dart';
import 'posts_screen.dart';
import 'user_search_screen.dart';
import 'provider_comparison_screen.dart';
import 'cache_debug_screen.dart';
import 'smart_cache_examples.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late PageController _pageController;
  int _currentIndex = 0;
  
  final List<TabData> _tabs = const [
    TabData(text: 'Users', icon: Icons.people),
    TabData(text: 'Users Async', icon: Icons.people_outline),
    TabData(text: 'Posts', icon: Icons.article),
    TabData(text: 'Search', icon: Icons.search),
    TabData(text: 'Mutations', icon: Icons.edit),
    TabData(text: 'BackgroundRefetchExample', icon: Icons.code),
    TabData(text: 'BackgroundForegroundExample', icon: Icons.code),
    TabData(text: 'LifecycleAwareExample', icon: Icons.code),
    TabData(text: 'WindowFocusExample', icon: Icons.code),
    TabData(text: 'SmartCacheComparisonExample', icon: Icons.abc),
  ];

  final List<Widget> _tabViews = const [
    UsersTab(),
    UsersAsyncTab(),
    PostsTab(),
    SearchTab(),
    MutationsTab(),
    BackgroundRefetchExample(),
    BackgroundForegroundExample(),
    LifecycleAwareExample(),
    WindowFocusExample(),
    SmartCacheComparisonScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Start with a large initial page to allow infinite scrolling in both directions
    const initialPage = 1000000;
    _pageController = PageController(initialPage: initialPage);
    _currentIndex = initialPage % _tabs.length;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentIndex = page % _tabs.length;
    });
  }

  void _onTabTapped(int index) {
    final currentPage = _pageController.page?.round() ?? 0;
    final currentTabIndex = currentPage % _tabs.length;
    
    // Calculate the shortest path to the target tab
    int targetPage;
    if (index == currentTabIndex) {
      return; // Already on the target tab
    }
    
    final forward = (index - currentTabIndex + _tabs.length) % _tabs.length;
    final backward = (currentTabIndex - index + _tabs.length) % _tabs.length;
    
    if (forward <= backward) {
      targetPage = currentPage + forward;
    } else {
      targetPage = currentPage - backward;
    }
    
    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: InfiniteTabBar(
            tabs: _tabs,
            currentIndex: _currentIndex,
            onTabTapped: _onTabTapped,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final tabIndex = index % _tabs.length;
          return _tabViews[tabIndex];
        },
      ),
    );
  }
}

class TabData {
  const TabData({required this.text, required this.icon});
  
  final String text;
  final IconData icon;
}

class InfiniteTabBar extends StatelessWidget {
  const InfiniteTabBar({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabTapped,
  });

  final List<TabData> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabTapped;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kToolbarHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final isSelected = index == currentIndex;
          final tab = tabs[index];
          
          return GestureDetector(
            onTap: () => onTabTapped(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: isSelected 
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 1,
                      )
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tab.icon,
                    size: 20,
                    color: isSelected 
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    tab.text,
                    style: TextStyle(
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
              
              if(!ref.context.mounted){
                return;
              }
              
              try {
                final notifier = ref.read(deleteUserMutationProvider(user.id).notifier);
                await notifier.mutate(user.id);
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
    final createUserMutation = ref.watch(createUserMutationProvider);

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
                      await ref.read(createUserMutationProvider.notifier).mutate({
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

class UsersAsyncTab extends ConsumerWidget {
  const UsersAsyncTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(usersAsyncQueryProvider);

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(usersAsyncQueryProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (users) => RefreshIndicator(
        onRefresh: () async {
          final notifier = ref.read(usersAsyncQueryProvider.notifier);
          await notifier.refetch();
        },
        child: Column(
          children: [
            // Users list
            Expanded(
              child: ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  return AsyncUserListTile(user: user);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AsyncUserListTile extends ConsumerWidget {
  const AsyncUserListTile({super.key, required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the individual user using the async family provider
    final userAsync = ref.watch(userAsyncQueryProviderFamily(user.id));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: userAsync.when(
        loading: () => ListTile(
          leading: CircleAvatar(
            backgroundImage: user.avatar != null ? NetworkImage(user.avatar!) : null,
            child: user.avatar == null ? Text(user.name[0]) : null,
          ),
          title: Text(user.name),
          subtitle: const Text('Loading details...'),
          trailing: const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (error, stackTrace) => ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.red[100],
            child: Icon(Icons.error, color: Colors.red[700]),
          ),
          title: Text(user.name),
          subtitle: Text('Error: $error'),
          trailing: IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(userAsyncQueryProviderFamily(user.id)),
          ),
        ),
        data: (detailedUser) => ListTile(
          leading: CircleAvatar(
            backgroundImage: detailedUser.avatar != null ? NetworkImage(detailedUser.avatar!) : null,
            child: detailedUser.avatar == null ? Text(detailedUser.name[0]) : null,
          ),
          title: Text(detailedUser.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(detailedUser.email),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.check_circle, size: 12, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Loaded via AsyncQueryProviderFamily',
                    style: TextStyle(
                      fontSize: 6,
                      color: Colors.green[600],
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                onPressed: () async {
                  final notifier = ref.read(userAsyncQueryProviderFamily(user.id).notifier);
                  await notifier.refetch();
                },
                tooltip: 'Refresh this user',
              ),
              IconButton(
                icon: Icon(Icons.delete, size: 18, color: Colors.red[600]),
                onPressed: () => _showDeleteConfirmation(context, ref, detailedUser),
                tooltip: 'Delete user',
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserDetailAsyncScreen(userId: detailedUser.id),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Are you sure you want to delete ${user.name}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          Consumer(
            builder: (context, ref, child) {
              final deleteState = ref.watch(deleteUserMutationProvider2(user.id));
              
              if (deleteState.isLoading) {
                return ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[300],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text('Deleting...'),
                    ],
                  ),
                );
              }
              
              if (deleteState.isSuccess) {
                return ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Deleted!'),
                );
              }
              
              if (deleteState.hasError) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Error: ${deleteState.error}', 
                         style: const TextStyle(color: Colors.red, fontSize: 12)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final notifier = ref.read(deleteUserMutationProvider2(user.id).notifier);
                        await notifier.mutate(user.id);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry Delete'),
                    ),
                  ],
                );
              }
              
              // Default idle state
              return ElevatedButton(
                onPressed: () async {
                  final notifier = ref.read(deleteUserMutationProvider2(user.id).notifier);
                  await notifier.mutate(user.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${user.name} deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Delete'),
              );
            },
          ),
        ],
      ),
    );
  }
}
