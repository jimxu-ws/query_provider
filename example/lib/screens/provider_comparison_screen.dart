import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';

import '../providers/user_providers.dart';
import '../models/user.dart';

class ProviderComparisonScreen extends ConsumerWidget {
  const ProviderComparisonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const userId = 5; // Fixed user ID for comparison

    // Different approaches to fetch the same user
    final functionApproachState = ref.watch(userQueryProvider(userId));
    final familyApproachState = ref.watch(userQueryProviderFamily(userId));
    final fixedParamsState = ref.watch(userQueryWithParams(userId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Provider Approaches Comparison'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Refresh all approaches
              ref.read(userQueryProvider(userId).notifier).refetch();
              ref.read(userQueryProviderFamily(userId).notifier).refetch();
              ref.read(userQueryWithParams(userId).notifier).refetch();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fetching User ID: $userId',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'All three approaches fetch the same user but use different provider patterns:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            
            // Function Approach
            _buildApproachCard(
              context,
              title: '1. Function Approach',
              description: 'userQueryProvider(userId) - Creates provider in function',
              code: '''
StateNotifierProvider<QueryNotifier<User>, QueryState<User>> userQueryProvider(int userId) {
  return queryProvider<User>(
    name: 'user-\$userId',
    queryFn: () => ApiService.fetchUser(userId),
  );
}

// Usage: ref.watch(userQueryProvider(5))''',
              state: functionApproachState,
              pros: [
                'Simple and straightforward',
                'Easy to understand',
                'Flexible parameter handling',
              ],
              cons: [
                'Creates new provider each call',
                'More verbose for multiple parameters',
                'Manual cache key management',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Family Approach
            _buildApproachCard(
              context,
              title: '2. Family Approach (Recommended)',
              description: 'userQueryProviderFamily(userId) - Uses StateNotifierProvider.family',
              code: '''
final userQueryProviderFamily = queryProviderFamily<User, int>(
  name: 'user',
  queryFn: ApiService.fetchUser,
);

// Usage: ref.watch(userQueryProviderFamily(5))''',
              state: familyApproachState,
              pros: [
                'Optimal performance',
                'Automatic provider caching',
                'Clean, reusable code',
                'Riverpod best practices',
              ],
              cons: [
                'Slightly more complex setup',
                'Requires understanding of families',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Fixed Parameters Approach
            _buildApproachCard(
              context,
              title: '3. Fixed Parameters Approach',
              description: 'userQueryWithParams(userId) - Baked-in parameters',
              code: '''
StateNotifierProvider<QueryNotifier<User>, QueryState<User>> userQueryWithParams(int userId) {
  return queryProviderWithParams<User, int>(
    name: 'user',
    params: userId,
    queryFn: ApiService.fetchUser,
  );
}

// Usage: ref.watch(userQueryWithParams(5))''',
              state: fixedParamsState,
              pros: [
                'Simple usage',
                'No parameters needed when watching',
                'Good for const parameters',
              ],
              cons: [
                'Less flexible',
                'Parameter frozen at creation',
                'Not suitable for dynamic values',
              ],
            ),
            
            const SizedBox(height: 24),
            
            _buildRecommendationCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildApproachCard(
    BuildContext context, {
    required String title,
    required String description,
    required String code,
    required QueryState<User> state,
    required List<String> pros,
    required List<String> cons,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // State Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: state.when(
                idle: () => const Text('State: Idle'),
                loading: () => const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 8),
                    Text('State: Loading...'),
                  ],
                ),
                success: (user) => Text('State: Success - ${user.name}'),
                error: (error, _) => Text('State: Error - $error'),
                refetching: (user) => Text('State: Refetching - ${user.name}'),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Code Example
            ExpansionTile(
              title: const Text('Code Example'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Pros and Cons
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pros:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      ...pros.map((pro) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check, color: Colors.green, size: 16),
                            const SizedBox(width: 4),
                            Expanded(child: Text(pro, style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cons:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      ...cons.map((con) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning, color: Colors.orange, size: 16),
                            const SizedBox(width: 4),
                            Expanded(child: Text(con, style: const TextStyle(fontSize: 12))),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(BuildContext context) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Recommendation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '🏆 Use Family Approach (Option 2) in 95% of cases',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Best performance and memory efficiency\n'
              '• Follows Riverpod best practices\n'
              '• Clean, reusable code\n'
              '• Automatic provider lifecycle management',
            ),
            const SizedBox(height: 12),
            const Text(
              'Use Function Approach when you need complex parameter logic or custom provider creation.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            const Text(
              'Use Fixed Parameters Approach only for truly constant, compile-time known values.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
