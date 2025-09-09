import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';

// Mock API service
class NewsService {
  static Future<List<String>> getLatestNews() async {
    await Future.delayed(const Duration(seconds: 1));
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return [
      'Breaking: News story ${timestamp % 1000}',
      'Update: Market changes ${(timestamp + 100) % 1000}',
      'Sports: Game result ${(timestamp + 200) % 1000}',
    ];
  }
}

// Query provider with background refetching
final newsProvider = queryProvider<List<String>>(
  name: 'latest-news',
  queryFn: NewsService.getLatestNews,
  options: const QueryOptions(
    // 🔄 Background refetch every 30 seconds
    refetchInterval: Duration(seconds: 30),
    
    // 📊 Data is stale after 10 seconds
    staleTime: Duration(seconds: 10),
    
    // 👀 Keep showing old data during background updates
    keepPreviousData: true,
    
    // 🎯 Cache for 5 minutes
    cacheTime: Duration(minutes: 5),
  ),
);

class BackgroundRefetchExample extends ConsumerWidget {
  const BackgroundRefetchExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newsState = ref.watch(newsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Refetch Demo'),
        actions: [
          // Manual refetch button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(newsProvider.notifier).refetch(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator
            _buildStatusCard(newsState),
            
            const SizedBox(height: 16),
            
            // News content
            Expanded(
              child: newsState.when(
                idle: () => const Center(child: Text('Ready to load news')),
                loading: () => const Center(child: CircularProgressIndicator()),
                success: (news) => _buildNewsList(news, isRefetching: false),
                error: (error, _) => Center(child: Text('Error: $error')),
                refetching: (previousNews) => _buildNewsList(
                  previousNews, 
                  isRefetching: true,
                ),
              ) ?? const Center(child: Text('Unknown state')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(QueryState<List<String>> state) {
    final isRefetching = state is QueryRefetching;
    final hasData = state.hasData;
    
    return Card(
      color: isRefetching 
          ? Colors.orange[50] 
          : hasData 
              ? Colors.green[50] 
              : Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              isRefetching 
                  ? Icons.sync 
                  : hasData 
                      ? Icons.check_circle 
                      : Icons.info,
              color: isRefetching 
                  ? Colors.orange 
                  : hasData 
                      ? Colors.green 
                      : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isRefetching 
                        ? '🔄 Updating in background...' 
                        : hasData 
                            ? '✅ News is up to date' 
                            : 'ℹ️ Loading news...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRefetching 
                        ? 'Showing previous data while fetching updates'
                        : hasData 
                            ? 'Auto-refresh every 30 seconds'
                            : 'Fetching latest news stories',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsList(List<String> news, {required bool isRefetching}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Latest News',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isRefetching) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Last updated: ${DateTime.now().toString().substring(11, 19)}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: news.length,
            itemBuilder: (context, index) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text('${index + 1}'),
                  ),
                  title: Text(news[index]),
                  subtitle: Text('Published ${DateTime.now().toString().substring(11, 16)}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Usage in main app
class BackgroundRefetchDemo extends StatelessWidget {
  const BackgroundRefetchDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Background Refetch Demo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const BackgroundRefetchExample(),
      ),
    );
  }
}
