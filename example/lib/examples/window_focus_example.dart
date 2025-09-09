import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';

// Mock API service for desktop/web data
class DesktopDataService {
  static int _updateCounter = 0;
  
  static Future<Map<String, dynamic>> getSystemInfo() async {
    await Future.delayed(const Duration(milliseconds: 600));
    _updateCounter++;
    
    return {
      'cpu_usage': '${45 + (_updateCounter * 3) % 40}%',
      'memory_usage': '${60 + (_updateCounter * 5) % 30}%',
      'disk_usage': '${30 + (_updateCounter * 2) % 50}%',
      'network_activity': '${_updateCounter * 12 % 100} KB/s',
      'last_update': DateTime.now().toIso8601String(),
      'update_count': _updateCounter,
    };
  }
  
  static Future<List<Map<String, dynamic>>> getActiveProcesses() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    
    return [
      {
        'name': 'Chrome',
        'cpu': '${15 + (timestamp % 20)}%',
        'memory': '${200 + (timestamp % 100)} MB',
        'pid': 1234,
      },
      {
        'name': 'VS Code',
        'cpu': '${8 + (timestamp % 15)}%',
        'memory': '${150 + (timestamp % 80)} MB',
        'pid': 5678,
      },
      {
        'name': 'Flutter App',
        'cpu': '${5 + (timestamp % 10)}%',
        'memory': '${80 + (timestamp % 40)} MB',
        'pid': 9012,
      },
    ];
  }
}

// 🖥️ System info query with window focus refetching
final systemInfoProvider = queryProvider<Map<String, dynamic>>(
  name: 'system-info',
  queryFn: DesktopDataService.getSystemInfo,
  options: const QueryOptions(
    // ⏰ Regular updates every 15 seconds
    refetchInterval: Duration(seconds: 15),
    
    // 🔄 Refetch when window gains focus (great for desktop apps)
    refetchOnWindowFocus: true,
    
    // 📱 Also refetch on app focus (mobile compatibility)
    refetchOnAppFocus: true,
    
    // ⏸️ Pause when app/window loses focus
    pauseRefetchInBackground: true,
    
    // 📊 Data is stale after 10 seconds
    staleTime: Duration(seconds: 10),
    
    keepPreviousData: true,
  ),
);

// 📊 Process list query
final processListProvider = queryProvider<List<Map<String, dynamic>>>(
  name: 'process-list',
  queryFn: DesktopDataService.getActiveProcesses,
  options: const QueryOptions(
    // ⚡ Frequent updates for real-time monitoring
    refetchInterval: Duration(seconds: 5),
    
    // 🔄 Immediate refresh when window gains focus
    refetchOnWindowFocus: true,
    
    // ⏸️ Stop monitoring when not focused
    pauseRefetchInBackground: true,
    
    staleTime: Duration(seconds: 3),
    keepPreviousData: true,
  ),
);

class WindowFocusExample extends ConsumerWidget {
  const WindowFocusExample({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemInfo = ref.watch(systemInfoProvider);
    final processList = ref.watch(processListProvider);
    final windowHasFocus = ref.watch(windowFocusStateProvider);
    final windowFocusSupported = ref.watch(windowFocusSupportedProvider);
    final appState = ref.watch(appLifecycleStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Window Focus Detection'),
        backgroundColor: windowHasFocus ? Colors.blue : Colors.grey,
        actions: [
          // Focus state indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  windowHasFocus ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white,
                ),
                const SizedBox(width: 4),
                Text(
                  windowHasFocus ? 'FOCUSED' : 'UNFOCUSED',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Window focus status
            _buildFocusStatusCard(windowHasFocus, windowFocusSupported, appState),
            
            const SizedBox(height: 16),
            
            // System information
            _buildSystemInfoCard(systemInfo),
            
            const SizedBox(height: 16),
            
            // Process list
            _buildProcessListCard(processList),
            
            const SizedBox(height: 16),
            
            // Instructions
            _buildInstructionsCard(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Manual focus simulation for testing
          ref.read(windowFocusManagerProvider).setWindowFocus(!windowHasFocus);
        },
        child: Icon(windowHasFocus ? Icons.visibility_off : Icons.visibility),
        tooltip: 'Toggle Focus (for testing)',
      ),
    );
  }

  Widget _buildFocusStatusCard(bool windowHasFocus, bool supported, AppLifecycleState appState) {
    return Card(
      color: windowHasFocus ? Colors.blue[50] : Colors.grey[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  windowHasFocus ? Icons.desktop_windows : Icons.desktop_access_disabled,
                  color: windowHasFocus ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Window Focus Status',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Window Focus', windowHasFocus ? 'FOCUSED' : 'UNFOCUSED', 
                windowHasFocus ? Colors.green : Colors.orange),
            _buildStatusRow('App Lifecycle', appState.name.toUpperCase(), Colors.blue),
            _buildStatusRow('Platform Support', supported ? 'SUPPORTED' : 'NOT SUPPORTED', 
                supported ? Colors.green : Colors.red),
            const SizedBox(height: 8),
            Text(
              windowHasFocus 
                  ? '🔄 Queries are actively refetching'
                  : '⏸️ Refetching paused (window not focused)',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemInfoCard(QueryState<Map<String, dynamic>> systemInfo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.computer, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'System Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (systemInfo is QueryRefetching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            systemInfo.when(
              idle: () => const Text('Ready to load system info'),
              loading: () => const Center(child: CircularProgressIndicator()),
              success: (data) => _buildSystemInfoContent(data),
              error: (error, _) => Text('Error: $error', style: const TextStyle(color: Colors.red)),
              refetching: (previousData) => _buildSystemInfoContent(previousData),
            ) ?? const Text('Unknown state'),
            const SizedBox(height: 8),
            Text(
              '⏰ Updates every 15 seconds • 🔄 Refetches on window focus',
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

  Widget _buildSystemInfoContent(Map<String, dynamic> data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricCard('CPU', data['cpu_usage'], Colors.red)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricCard('Memory', data['memory_usage'], Colors.orange)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildMetricCard('Disk', data['disk_usage'], Colors.blue)),
            const SizedBox(width: 8),
            Expanded(child: _buildMetricCard('Network', data['network_activity'], Colors.green)),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Last Update: ${data['last_update'].toString().substring(11, 19)} • Count: ${data['update_count']}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessListCard(QueryState<List<Map<String, dynamic>>> processList) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt, color: Colors.purple),
                const SizedBox(width: 8),
                const Text(
                  'Active Processes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (processList is QueryRefetching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            processList.when(
              idle: () => const Text('Ready to load processes'),
              loading: () => const Center(child: CircularProgressIndicator()),
              success: (data) => _buildProcessList(data),
              error: (error, _) => Text('Error: $error', style: const TextStyle(color: Colors.red)),
              refetching: (previousData) => _buildProcessList(previousData),
            ) ?? const Text('Unknown state'),
            const SizedBox(height: 8),
            Text(
              '⚡ Updates every 5 seconds • 🔄 Real-time when focused',
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

  Widget _buildProcessList(List<Map<String, dynamic>> processes) {
    return Column(
      children: processes.map((process) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple[200]!),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  process['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(child: Text('CPU: ${process['cpu']}')),
              Expanded(child: Text('RAM: ${process['memory']}')),
              Text(
                'PID: ${process['pid']}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
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
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber[700]),
                const SizedBox(width: 8),
                Text(
                  'How to Test Window Focus',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInstructionPoint(
              '🖱️ Click Away',
              'Click on another application or browser tab to lose window focus',
            ),
            _buildInstructionPoint(
              '🔄 Return Focus',
              'Click back on this app to regain focus and trigger refetch',
            ),
            _buildInstructionPoint(
              '📱 Mobile Testing',
              'On mobile, switch apps and return to test app lifecycle detection',
            ),
            _buildInstructionPoint(
              '🧪 Manual Toggle',
              'Use the floating action button to manually simulate focus changes',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '💡 Window focus detection works best on desktop and web platforms. '
                'On mobile, app lifecycle detection is used instead.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber[800],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionPoint(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.amber[700],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Usage in main app
class WindowFocusDemo extends StatelessWidget {
  const WindowFocusDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Window Focus Detection Demo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const WindowFocusExample(),
      ),
    );
  }
}
