import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';

// Mock API service for demonstrating autodisposed queries
class TemporaryDataService {
  static int _requestCounter = 0;
  static final Map<String, int> _providerInstances = {};
  
  /// Simulates fetching user session data that's only needed temporarily
  static Future<Map<String, dynamic>> getUserSession() async {
    await Future.delayed(const Duration(milliseconds: 600));
    _requestCounter++;
    
    return {
      'session_id': 'sess_${DateTime.now().millisecondsSinceEpoch}',
      'user_id': 12345,
      'username': 'john_doe',
      'last_activity': DateTime.now().toIso8601String(),
      'request_count': _requestCounter,
      'expires_in': 3600, // 1 hour
    };
  }
  
  /// Simulates fetching dashboard data that changes frequently
  static Future<Map<String, dynamic>> getDashboardData() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _requestCounter++;
    
    final now = DateTime.now();
    return {
      'timestamp': now.toIso8601String(),
      'active_users': 1250 + (_requestCounter * 3) % 100,
      'revenue_today': (15000 + (_requestCounter * 47) % 5000).toDouble(),
      'pending_orders': 23 + (_requestCounter * 2) % 10,
      'system_load': ((50 + (_requestCounter * 7) % 40) / 100).toStringAsFixed(2),
      'request_count': _requestCounter,
    };
  }
  
  /// Simulates fetching temporary cache data
  static Future<List<String>> getTemporaryCache(String cacheKey) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _requestCounter++;
    
    // Track provider instances for demonstration
    _providerInstances[cacheKey] = (_providerInstances[cacheKey] ?? 0) + 1;
    
    return [
      'Cache entry #${_providerInstances[cacheKey]} for $cacheKey',
      'Generated at: ${DateTime.now().toIso8601String()}',
      'Total requests: $_requestCounter',
      'This data will be cleaned up when widget is disposed',
    ];
  }
  
  /// Get provider instance counts for demonstration
  static Map<String, int> getProviderInstances() => Map.from(_providerInstances);
  
  /// Reset counters (for demo purposes)
  static void reset() {
    _requestCounter = 0;
    _providerInstances.clear();
  }
}

// 🔥 AutoDispose Async Query Provider Examples

/// User session provider - automatically disposed when not watched
/// Perfect for login screens, temporary user data, etc.
final userSessionProvider = autoDisposeAsyncQueryProvider<Map<String, dynamic>>(
  name: 'userSession',
  queryFn: TemporaryDataService.getUserSession,
  options: const QueryOptions(
    staleTime: Duration(minutes: 2),
    refetchOnWindowFocus: true,
    refetchOnMount: true,
  ),
);

/// Dashboard data provider - auto-disposed for memory efficiency
/// Great for dashboard widgets that are frequently navigated away from
final dashboardDataProvider = autoDisposeAsyncQueryProvider<Map<String, dynamic>>(
  name: 'dashboardData',
  queryFn: TemporaryDataService.getDashboardData,
  options: const QueryOptions(
    staleTime: Duration(seconds: 30),
    refetchInterval: Duration(seconds: 45), // Regular updates when active
    refetchOnWindowFocus: true,
    pauseRefetchInBackground: true,
  ),
);

/// Parameterized autodispose provider family for temporary cache data
final temporaryCacheProvider = autoDisposeAsyncQueryProviderFamily<List<String>, String>(
  name: 'temporaryCache',
  queryFn: TemporaryDataService.getTemporaryCache,
  options: const QueryOptions(
    staleTime: Duration(minutes: 1),
    refetchOnMount: false, // Don't refetch on mount for cache data
  ),
);

// 🔄 Regular (non-autodisposed) provider for comparison
final persistentDataProvider = asyncQueryProvider<Map<String, dynamic>>(
  name: 'persistentData',
  queryFn: TemporaryDataService.getDashboardData,
  options: const QueryOptions(
    staleTime: Duration(minutes: 5),
    cacheTime: Duration(minutes: 10),
  ),
);

class AutoDisposeAsyncExample extends ConsumerWidget {
  const AutoDisposeAsyncExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AutoDispose Async Query Examples'),
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Session'),
              Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
              Tab(icon: Icon(Icons.cached), text: 'Cache'),
              Tab(icon: Icon(Icons.compare), text: 'Compare'),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () {
                TemporaryDataService.reset();
                // Invalidate all providers to see the reset effect
                ref.invalidate(userSessionProvider);
                ref.invalidate(dashboardDataProvider);
                ref.invalidate(persistentDataProvider);
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Reset Demo',
            ),
          ],
        ),
        body: const TabBarView(
          children: [
            _UserSessionTab(),
            _DashboardTab(),
            _TemporaryCacheTab(),
            _ComparisonTab(),
          ],
        ),
      ),
    );
  }
}

/// Tab demonstrating user session autodispose provider
class _UserSessionTab extends ConsumerWidget {
  const _UserSessionTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(userSessionProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: '👤 User Session Provider',
            description: 'This provider automatically disposes when not watched. '
                'Perfect for login screens or temporary user data.',
            color: Colors.blue,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_circle, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Session Data',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (sessionAsync.isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  sessionAsync.when(
                    loading: () => const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading user session...'),
                        ],
                      ),
                    ),
                    error: (error, stack) => Column(
                      children: [
                        Icon(Icons.error, color: Colors.red[400], size: 48),
                        const SizedBox(height: 8),
                        Text('Error: $error', style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                    data: (session) => _buildSessionData(session),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => ref.invalidate(userSessionProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Session'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final notifier = ref.read(userSessionProvider.notifier);
                    await notifier.refetch();
                  },
                  icon: const Icon(Icons.sync),
                  label: const Text('Refetch'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionData(Map<String, dynamic> session) {
    return Column(
      children: [
        _buildDataRow('Session ID', session['session_id'], Icons.fingerprint),
        _buildDataRow('User ID', session['user_id'].toString(), Icons.person),
        _buildDataRow('Username', session['username'], Icons.account_circle),
        _buildDataRow('Last Activity', session['last_activity'].toString().substring(11, 19), Icons.access_time),
        _buildDataRow('Request Count', session['request_count'].toString(), Icons.analytics),
        _buildDataRow('Expires In', '${session['expires_in']}s', Icons.timer),
      ],
    );
  }
}

/// Tab demonstrating dashboard autodispose provider
class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardAsync = ref.watch(dashboardDataProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: '📊 Dashboard Data Provider',
            description: 'Auto-disposed provider with background refetching. '
                'Memory efficient for dashboard widgets.',
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.dashboard, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text(
                        'Dashboard Metrics',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      if (dashboardAsync.isLoading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  dashboardAsync.when(
                    loading: () => const Center(
                      child: Column(
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading dashboard data...'),
                        ],
                      ),
                    ),
                    error: (error, stack) => Column(
                      children: [
                        Icon(Icons.error, color: Colors.red[400], size: 48),
                        const SizedBox(height: 8),
                        Text('Error: $error', style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                    data: (dashboard) => _buildDashboardData(dashboard),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            title: '🔄 Auto-Refetch Info',
            description: 'This provider refetches every 45 seconds when active, '
                'pauses in background, and refreshes on window focus.',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardData(Map<String, dynamic> dashboard) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricCard('Active Users', dashboard['active_users'].toString(), Icons.people, Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricCard('Revenue', '\$${dashboard['revenue_today'].toStringAsFixed(0)}', Icons.attach_money, Colors.green)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMetricCard('Pending Orders', dashboard['pending_orders'].toString(), Icons.shopping_cart, Colors.orange)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricCard('System Load', '${(double.parse(dashboard['system_load']) * 100).toInt()}%', Icons.memory, Colors.red)),
          ],
        ),
        const SizedBox(height: 16),
        _buildDataRow('Last Updated', dashboard['timestamp'].toString().substring(11, 19), Icons.update),
        _buildDataRow('Total Requests', dashboard['request_count'].toString(), Icons.analytics),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
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
}

/// Tab demonstrating parameterized autodispose provider family
class _TemporaryCacheTab extends ConsumerStatefulWidget {
  const _TemporaryCacheTab();

  @override
  ConsumerState<_TemporaryCacheTab> createState() => _TemporaryCacheTabState();
}

class _TemporaryCacheTabState extends ConsumerState<_TemporaryCacheTab> {
  final List<String> _activeCaches = ['cache-1', 'cache-2'];
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerInstances = TemporaryDataService.getProviderInstances();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: '🗄️ Temporary Cache Provider Family',
            description: 'Parameterized autodispose providers. Each cache key gets its own provider instance that auto-disposes.',
            color: Colors.purple,
          ),
          const SizedBox(height: 16),
          
          // Add new cache section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Cache',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: 'Enter cache key (e.g., cache-3)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (_controller.text.isNotEmpty && !_activeCaches.contains(_controller.text)) {
                            setState(() {
                              _activeCaches.add(_controller.text);
                            });
                            _controller.clear();
                          }
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Provider instances info
          if (providerInstances.isNotEmpty)
            Card(
              color: Colors.amber[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info, color: Colors.amber),
                        SizedBox(width: 8),
                        Text(
                          'Provider Instances Created',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...providerInstances.entries.map((entry) => 
                      Text('${entry.key}: ${entry.value} instance(s)')
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          // Active caches
          ..._activeCaches.map((cacheKey) => _buildCacheCard(cacheKey)),
        ],
      ),
    );
  }

  Widget _buildCacheCard(String cacheKey) {
    final cacheAsync = ref.watch(temporaryCacheProvider(cacheKey));
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cached, color: Colors.purple[600]),
                const SizedBox(width: 8),
                Text(
                  'Cache: $cacheKey',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _activeCaches.remove(cacheKey);
                    });
                  },
                  icon: const Icon(Icons.close, color: Colors.red),
                  tooltip: 'Remove cache (will auto-dispose provider)',
                ),
              ],
            ),
            const SizedBox(height: 12),
            cacheAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, stack) => Text('Error: $error', style: const TextStyle(color: Colors.red)),
              data: (cacheData) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: cacheData.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $item', style: const TextStyle(fontSize: 14)),
                )).toList(),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(temporaryCacheProvider(cacheKey)),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tab comparing autodisposed vs regular providers
class _ComparisonTab extends ConsumerWidget {
  const _ComparisonTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoDisposeAsync = ref.watch(dashboardDataProvider);
    final persistentAsync = ref.watch(persistentDataProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            title: '⚖️ AutoDispose vs Regular Comparison',
            description: 'Both providers fetch the same data, but behave differently in terms of lifecycle and memory management.',
            color: Colors.teal,
          ),
          const SizedBox(height: 16),
          
          // AutoDispose provider
          Card(
            color: Colors.purple[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_delete, color: Colors.purple[700]),
                      const SizedBox(width: 8),
                      Text(
                        'AutoDispose Provider',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '✅ Automatically disposes when not watched\n'
                    '✅ Memory efficient\n'
                    '✅ Good for temporary/screen-specific data\n'
                    '✅ Automatic cleanup of timers and listeners\n'
                    '⚠️ Data is lost when disposed',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  autoDisposeAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stack) => Text('Error: $error'),
                    data: (data) => Text(
                      'Last updated: ${data['timestamp'].toString().substring(11, 19)}\n'
                      'Request #${data['request_count']}',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Regular provider
          Card(
            color: Colors.blue[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storage, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Regular Provider',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '✅ Persists across widget rebuilds\n'
                    '✅ Shared state across multiple widgets\n'
                    '✅ Long-lived cache\n'
                    '⚠️ Manual disposal required\n'
                    '⚠️ Can cause memory leaks if not managed properly',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  persistentAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (error, stack) => Text('Error: $error'),
                    data: (data) => Text(
                      'Last updated: ${data['timestamp'].toString().substring(11, 19)}\n'
                      'Request #${data['request_count']}',
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => ref.invalidate(dashboardDataProvider),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                  child: const Text('Refresh AutoDispose'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => ref.invalidate(persistentDataProvider),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                  child: const Text('Refresh Regular'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Helper widgets
Widget _buildInfoCard({
  required String title,
  required String description,
  required Color color,
}) {
  return Card(
    color: color.withOpacity(0.1),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildDataRow(String label, String value, IconData icon) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
      ],
    ),
  );
}

// Usage in main app
class AutoDisposeAsyncDemo extends StatelessWidget {
  const AutoDisposeAsyncDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'AutoDispose Async Query Demo',
        theme: ThemeData(primarySwatch: Colors.purple),
        home: const AutoDisposeAsyncExample(),
      ),
    );
  }
}
