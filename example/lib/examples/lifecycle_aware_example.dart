import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';

// Mock API service that simulates server data
class ServerDataService {
  static int _counter = 0;
  
  static Future<Map<String, dynamic>> getServerStatus() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _counter++;
    
    return {
      'server_time': DateTime.now().toIso8601String(),
      'request_count': _counter,
      'status': 'online',
      'load': (50 + (_counter * 7) % 50).toString() + '%',
    };
  }
  
  static Future<List<String>> getRealtimeNotifications() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    return [
      'New message received ${timestamp % 1000}',
      'System update available',
      'User logged in from new device',
    ];
  }
}

// 🔄 Lifecycle-aware server status query
final serverStatusProvider = queryProvider<Map<String, dynamic>>(
  name: 'server-status',
  queryFn: ServerDataService.getServerStatus,
  options: const QueryOptions(
    // ⏰ Refetch every 10 seconds when app is active
    refetchInterval: Duration(seconds: 10),
    
    // 🛑 Pause refetching when app goes to background
    pauseRefetchInBackground: true,
    
    // 🔄 Refetch when app comes back to foreground
    refetchOnAppFocus: true,
    
    // 📊 Data is stale after 5 seconds
    staleTime: Duration(seconds: 5),
    
    // 👀 Keep showing old data during refetch
    keepPreviousData: true,
  ),
);

// 📱 Real-time notifications query
final notificationsProvider = queryProvider<List<String>>(
  name: 'notifications',
  queryFn: ServerDataService.getRealtimeNotifications,
  options: const QueryOptions(
    // ⚡ Frequent updates when app is active
    refetchInterval: Duration(seconds: 3),
    
    // 🛑 Stop when in background to save battery
    pauseRefetchInBackground: true,
    
    // 🔄 Immediate refresh when returning to app
    refetchOnAppFocus: true,
    
    // 📊 Always consider stale for real-time data
    staleTime: Duration(seconds: 1),
    
    keepPreviousData: true,
  ),
);

class LifecycleAwareExample extends ConsumerWidget {
  const LifecycleAwareExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverStatus = ref.watch(serverStatusProvider);
    final notifications = ref.watch(notificationsProvider);
    final appState = ref.watch(appLifecycleStateProvider);
    final isInForeground = ref.watch(isAppInForegroundProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lifecycle-Aware Queries'),
        backgroundColor: isInForeground ? Colors.green : Colors.orange,
        actions: [
          // App state indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Chip(
              label: Text(
                isInForeground ? 'ACTIVE' : 'BACKGROUND',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: isInForeground ? Colors.green[100] : Colors.orange[100],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App lifecycle status
            _buildLifecycleCard(appState, isInForeground),
            
            const SizedBox(height: 16),
            
            // Server status section
            _buildServerStatusCard(serverStatus),
            
            const SizedBox(height: 16),
            
            // Notifications section
            _buildNotificationsCard(notifications),
            
            const SizedBox(height: 16),
            
            // Explanation card
            _buildExplanationCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildLifecycleCard(AppLifecycleState appState, bool isInForeground) {
    return Card(
      color: isInForeground ? Colors.green[50] : Colors.orange[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isInForeground ? Icons.visibility : Icons.visibility_off,
                  color: isInForeground ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text(
                  'App Lifecycle State',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Current State: ${appState.name.toUpperCase()}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isInForeground ? Colors.green[700] : Colors.orange[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isInForeground
                  ? '🔄 Queries are actively refetching'
                  : '⏸️ Background refetching is paused',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerStatusCard(QueryState<Map<String, dynamic>> serverStatus) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.dns, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Server Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (serverStatus is QueryRefetching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            serverStatus.when(
              idle: () => const Text('Ready to check server status'),
              loading: () => const Center(child: CircularProgressIndicator()),
              success: (data) => _buildServerStatusContent(data),
              error: (error, _) => Text('Error: $error', style: const TextStyle(color: Colors.red)),
              refetching: (previousData) => _buildServerStatusContent(previousData),
            ) ?? const Text('Unknown state'),
            const SizedBox(height: 8),
            Text(
              '⏰ Refetches every 10 seconds (when app is active)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerStatusContent(Map<String, dynamic> data) {
    return Column(
      children: [
        _buildStatusRow('Status', data['status'], Colors.green),
        _buildStatusRow('Server Load', data['load'], Colors.orange),
        _buildStatusRow('Request Count', data['request_count'].toString(), Colors.blue),
        _buildStatusRow('Last Update', data['server_time'].toString().substring(11, 19), Colors.grey),
      ],
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsCard(QueryState<List<String>> notifications) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Real-time Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (notifications is QueryRefetching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            notifications.when(
              idle: () => const Text('Ready to load notifications'),
              loading: () => const Center(child: CircularProgressIndicator()),
              success: (data) => _buildNotificationsList(data),
              error: (error, _) => Text('Error: $error', style: const TextStyle(color: Colors.red)),
              refetching: (previousData) => _buildNotificationsList(previousData),
            ) ?? const Text('Unknown state'),
            const SizedBox(height: 8),
            Text(
              '⚡ Refetches every 3 seconds (paused in background)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsList(List<String> notifications) {
    return Column(
      children: notifications.map((notification) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.circle, size: 8, color: Colors.purple[400]),
              const SizedBox(width: 8),
              Expanded(child: Text(notification)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExplanationCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'How It Works',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildExplanationPoint(
              '🔄 Active Refetching',
              'When app is in foreground, queries automatically refetch at their configured intervals',
            ),
            _buildExplanationPoint(
              '⏸️ Background Pause',
              'When app goes to background, automatic refetching is paused to save battery and data',
            ),
            _buildExplanationPoint(
              '🚀 Resume & Refresh',
              'When app returns to foreground, queries immediately check if data is stale and refetch if needed',
            ),
            _buildExplanationPoint(
              '📱 Try It',
              'Switch to another app and come back to see the lifecycle-aware behavior in action!',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationPoint(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Usage in main app
class LifecycleAwareDemo extends StatelessWidget {
  const LifecycleAwareDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Lifecycle-Aware Queries Demo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const LifecycleAwareExample(),
      ),
    );
  }
}
