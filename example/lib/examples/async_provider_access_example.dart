import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';

import '../providers/user_providers.dart';
import '../models/user.dart';

class AsyncProviderAccessExample extends ConsumerWidget {
  const AsyncProviderAccessExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Async Provider Access'),
        backgroundColor: Colors.purple[600],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header explanation
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.purple[700]),
                      const SizedBox(width: 8),
                      Text(
                        'How to Access AsyncQueryProvider',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'AsyncQueryProvider returns AsyncValue<T>, not QueryState<T>.\n'
                    'Here are the correct ways to access it:',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Method 1: Access AsyncValue
            _buildMethodCard(
              'Method 1: Access AsyncValue',
              'ref.read(usersAsyncQueryProvider)',
              Colors.blue,
              () => _demonstrateAsyncValueAccess(context, ref),
            ),
            
            // Method 2: Access Notifier
            _buildMethodCard(
              'Method 2: Access Notifier',
              'ref.read(usersAsyncQueryProvider.notifier)',
              Colors.green,
              () => _demonstrateNotifierAccess(context, ref),
            ),
            
            // Method 3: Access Cache Directly
            _buildMethodCard(
              'Method 3: Access Cache Directly',
              'queryClient.getQueryData("users-async")',
              Colors.orange,
              () => _demonstrateCacheAccess(context, ref),
            ),
            
            const SizedBox(height: 24),
            
            // Current state display
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current State:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Consumer(
                        builder: (context, ref, child) {
                          final usersAsync = ref.watch(usersAsyncQueryProvider);
                          
                          return usersAsync.when(
                            loading: () => const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Loading users...'),
                                ],
                              ),
                            ),
                            error: (error, stack) => Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.error, size: 48, color: Colors.red[300]),
                                  const SizedBox(height: 16),
                                  Text('Error: $error'),
                                ],
                              ),
                            ),
                            data: (users) => ListView.builder(
                              itemCount: users.length,
                              itemBuilder: (context, index) {
                                final user = users[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text('${index + 1}'),
                                  ),
                                  title: Text(user.name),
                                  subtitle: Text(user.email),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodCard(String title, String code, Color color, VoidCallback onPressed) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
              ),
              child: const Text('Try It'),
            ),
          ],
        ),
      ),
    );
  }

  void _demonstrateAsyncValueAccess(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.read(usersAsyncQueryProvider);
    
    String message = usersAsync.when(
      loading: () => 'AsyncValue is currently loading',
      error: (error, stack) => 'AsyncValue has error: $error',
      data: (users) => 'AsyncValue has ${users.length} users',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _demonstrateNotifierAccess(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(usersAsyncQueryProvider.notifier);
    
    // You can call methods on the notifier
    notifier.refetch().then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Refetch triggered via notifier'),
          backgroundColor: Colors.green,
        ),
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Refetch failed: $error'),
          backgroundColor: Colors.red,
        ),
      );
    });
  }

  void _demonstrateCacheAccess(BuildContext context, WidgetRef ref) {
    final queryClient = ref.read(queryClientProvider);
    final cachedUsers = queryClient.getQueryData<List<User>>('users-async');
    
    String message = cachedUsers != null 
        ? 'Cache has ${cachedUsers.length} users'
        : 'No data in cache';
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
      ),
    );
  }
}
