import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';

class CacheDebugScreen extends ConsumerStatefulWidget {
  const CacheDebugScreen({super.key});

  @override
  ConsumerState<CacheDebugScreen> createState() => _CacheDebugScreenState();
}

class _CacheDebugScreenState extends ConsumerState<CacheDebugScreen> {
  late Timer _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Auto-refresh every 2 seconds to show live cache updates
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final queryClient = ref.read(queryClientProvider);
    final cache = getGlobalQueryCache();
    final stats = cache.stats;
    final cacheKeys = cache.keys;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cache Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              cache.clear();
              setState(() {});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cache Statistics Card
            _buildStatsCard(stats, cache),
            
            const SizedBox(height: 16),
            
            // Cache Actions Card
            _buildActionsCard(cache, queryClient),
            
            const SizedBox(height: 16),
            
            // Cache Entries List
            _buildCacheEntriesCard(cache, cacheKeys),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(QueryCacheStats stats, QueryCache cache) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Cache Statistics',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Entries',
                    stats.totalEntries.toString(),
                    Icons.storage,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Stale Entries',
                    stats.staleEntries.toString(),
                    Icons.schedule,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Hit Rate',
                    '${(stats.hitRate * 100).toStringAsFixed(1)}%',
                    Icons.trending_up,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Evictions',
                    stats.evictionCount.toString(),
                    Icons.delete_sweep,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Cache Hits',
                    stats.hitCount.toString(),
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Cache Misses',
                    stats.missCount.toString(),
                    Icons.cancel,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Next cleanup info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Icon(Icons.schedule, color: Colors.purple, size: 24),
                  const SizedBox(height: 4),
                  Text(
                    _getNextCleanupText(cache),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple[700],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Next Cleanup',
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(QueryCache cache, QueryClient queryClient) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  'Cache Actions',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    final cleaned = cache.cleanup();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Cleaned up $cleaned expired entries')),
                    );
                  },
                  icon: const Icon(Icons.cleaning_services),
                  label: const Text('Cleanup Expired'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    cache.resetStats();
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Statistics reset')),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset Stats'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final removed = cache.removeByPattern('user');
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Removed $removed user entries')),
                    );
                  },
                  icon: const Icon(Icons.person_remove),
                  label: const Text('Clear Users'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final removed = cache.removeByPattern('post');
                    setState(() {});
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Removed $removed post entries')),
                    );
                  },
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('Clear Posts'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheEntriesCard(QueryCache cache, List<String> cacheKeys) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list, color: Colors.green),
                const SizedBox(width: 8),
                Text(
                  'Cache Entries (${cacheKeys.length})',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (cacheKeys.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No cache entries',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...cacheKeys.map((key) => _buildCacheEntryTile(cache, key)),
          ],
        ),
      ),
    );
  }

  Widget _buildCacheEntryTile(QueryCache cache, String key) {
    final entry = cache.get(key);
    if (entry == null) return const SizedBox.shrink();

    final isStale = entry.isStale;
    final hasData = entry.hasData;
    final hasError = entry.hasError;
    
    final now = DateTime.now();
    final age = now.difference(entry.fetchedAt);
    final ageText = _formatDuration(age);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isStale ? Colors.orange[50] : (hasError ? Colors.red[50] : Colors.green[50]),
      child: ExpansionTile(
        leading: Icon(
          hasError ? Icons.error : (hasData ? Icons.check_circle : Icons.help),
          color: hasError ? Colors.red : (hasData ? Colors.green : Colors.grey),
        ),
        title: Text(
          key,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        ),
        subtitle: Text(
          'Age: $ageText • ${hasError ? 'Error' : (hasData ? 'Has Data' : 'No Data')} • ${isStale ? 'Stale' : 'Fresh'}',
          style: TextStyle(
            fontSize: 12,
            color: isStale ? Colors.orange[700] : Colors.grey[600],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEntryDetail('Fetched At', entry.fetchedAt.toString()),
                _buildEntryDetail('Stale Time', entry.options.staleTime.toString()),
                _buildEntryDetail('Cache Time', entry.options.cacheTime.toString()),
                if (hasData) _buildEntryDetail('Data Type', entry.data.runtimeType.toString()),
                if (hasError) _buildEntryDetail('Error', entry.error.toString()),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        cache.remove(key);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Removed cache entry: $key')),
                        );
                      },
                      icon: const Icon(Icons.delete, size: 16),
                      label: const Text('Remove'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  String _getNextCleanupText(QueryCache cache) {
    final nextCleanup = cache.nextCleanupTime;
    if (nextCleanup == null) {
      return 'Not scheduled';
    }

    final now = DateTime.now();
    if (nextCleanup.isBefore(now)) {
      return 'Overdue';
    }

    final timeUntil = nextCleanup.difference(now);
    return 'In ${_formatDuration(timeUntil)}';
  }
}
