import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';

// Mock API services that simulate real-world scenarios
class WeatherService {
  static int _requestCount = 0;
  
  static Future<Map<String, dynamic>> getCurrentWeather() async {
    await Future.delayed(const Duration(milliseconds: 800));
    _requestCount++;
    
    final temps = [18, 22, 25, 19, 21, 24, 20];
    final conditions = ['Sunny', 'Cloudy', 'Rainy', 'Partly Cloudy', 'Clear'];
    final timestamp = DateTime.now();
    
    return {
      'temperature': temps[_requestCount % temps.length],
      'condition': conditions[_requestCount % conditions.length],
      'humidity': 45 + (_requestCount * 3) % 40,
      'wind_speed': 5 + (_requestCount * 2) % 15,
      'last_updated': timestamp.toIso8601String(),
      'request_count': _requestCount,
    };
  }
}

class NewsService {
  static int _articleCount = 0;
  
  static Future<List<Map<String, dynamic>>> getBreakingNews() async {
    await Future.delayed(const Duration(milliseconds: 600));
    _articleCount++;
    
    final headlines = [
      'Tech Giants Report Strong Quarterly Earnings',
      'New Climate Agreement Reached at Global Summit',
      'Revolutionary Medical Breakthrough Announced',
      'Space Mission Successfully Launches to Mars',
      'Economic Markets Show Positive Growth Trends',
    ];
    
    return List.generate(3, (index) {
      final articleIndex = (_articleCount + index) % headlines.length;
      return {
        'id': _articleCount * 10 + index,
        'headline': headlines[articleIndex],
        'timestamp': DateTime.now().subtract(Duration(minutes: index * 15)).toIso8601String(),
        'category': ['Technology', 'Politics', 'Health', 'Science', 'Business'][articleIndex],
      };
    });
  }
}

class StockService {
  static int _updateCount = 0;
  
  static Future<List<Map<String, dynamic>>> getStockPrices() async {
    await Future.delayed(const Duration(milliseconds: 400));
    _updateCount++;
    
    final stocks = ['AAPL', 'GOOGL', 'MSFT', 'AMZN', 'TSLA'];
    
    return stocks.map((symbol) {
      final basePrice = {'AAPL': 150, 'GOOGL': 2800, 'MSFT': 300, 'AMZN': 3200, 'TSLA': 800}[symbol]!;
      final change = ((_updateCount * 7) % 20) - 10; // -10 to +10
      
      return {
        'symbol': symbol,
        'price': basePrice + change,
        'change': change,
        'change_percent': (change / basePrice * 100).toStringAsFixed(2),
        'last_updated': DateTime.now().toIso8601String(),
      };
    }).toList();
  }
}

// 🌤️ Weather query - Updates every 2 minutes when app is active
final weatherProvider = queryProvider<Map<String, dynamic>>(
  name: 'current-weather',
  queryFn: WeatherService.getCurrentWeather,
  options: const QueryOptions(
    // ⏰ Regular updates when app is active
    refetchInterval: Duration(minutes: 2),
    
    // 🔄 Refresh when app comes back to foreground
    refetchOnAppFocus: true,
    
    // ⏸️ Pause updates when app goes to background
    pauseRefetchInBackground: true,
    
    // 📊 Data is stale after 1 minute
    staleTime: Duration(minutes: 1),
    
    // 👀 Keep showing old weather while updating
    keepPreviousData: true,
  ),
);

// 📰 News query - Frequent updates for breaking news
final newsProvider = queryProvider<List<Map<String, dynamic>>>(
  name: 'breaking-news',
  queryFn: NewsService.getBreakingNews,
  options: const QueryOptions(
    // ⚡ Frequent updates for breaking news
    refetchInterval: Duration(seconds: 30),
    
    // 🔄 Immediate refresh when returning to app
    refetchOnAppFocus: true,
    
    // ⏸️ Stop news updates in background to save battery
    pauseRefetchInBackground: true,
    
    // 📊 News is stale after 20 seconds
    staleTime: Duration(seconds: 20),
    
    keepPreviousData: true,
  ),
);

// 📈 Stock prices - Real-time when active, paused in background
final stocksProvider = queryProvider<List<Map<String, dynamic>>>(
  name: 'stock-prices',
  queryFn: StockService.getStockPrices,
  options: const QueryOptions(
    // 🚀 Very frequent updates for real-time trading
    refetchInterval: Duration(seconds: 10),
    
    // 🔄 Critical to refresh when returning to trading app
    refetchOnAppFocus: true,
    
    // ⏸️ Pause expensive stock updates in background
    pauseRefetchInBackground: true,
    
    // 📊 Stock data is stale after 5 seconds
    staleTime: Duration(seconds: 5),
    
    keepPreviousData: true,
  ),
);

class BackgroundForegroundExample extends ConsumerStatefulWidget {
  const BackgroundForegroundExample({super.key});

  @override
  ConsumerState<BackgroundForegroundExample> createState() => _BackgroundForegroundExampleState();
}

class _BackgroundForegroundExampleState extends ConsumerState<BackgroundForegroundExample> 
    with WidgetsBindingObserver {
  
  DateTime? _lastBackgroundTime;
  DateTime? _lastForegroundTime;
  int _backgroundCount = 0;
  int _foregroundCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastForegroundTime = DateTime.now();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        _lastBackgroundTime = DateTime.now();
        _backgroundCount++;
      } else if (state == AppLifecycleState.resumed) {
        _lastForegroundTime = DateTime.now();
        _foregroundCount++;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final weather = ref.watch(weatherProvider);
    final news = ref.watch(newsProvider);
    final stocks = ref.watch(stocksProvider);
    final appState = ref.watch(appLifecycleStateProvider);
    final isInForeground = ref.watch(isAppInForegroundProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Background/Foreground Demo'),
        backgroundColor: isInForeground ? Colors.green : Colors.orange,
        actions: [
          // App state indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isInForeground ? Colors.green[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isInForeground ? Icons.play_arrow : Icons.pause,
                  size: 16,
                  color: isInForeground ? Colors.green[700] : Colors.orange[700],
                ),
                const SizedBox(width: 4),
                Text(
                  isInForeground ? 'ACTIVE' : 'PAUSED',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isInForeground ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Manual refresh all queries
          await Future.wait([
            ref.read(weatherProvider.notifier).refetch(),
            ref.read(newsProvider.notifier).refetch(),
            ref.read(stocksProvider.notifier).refetch(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App lifecycle status
              _buildLifecycleCard(appState, isInForeground),
              
              const SizedBox(height: 16),
              
              // Weather section
              _buildWeatherCard(weather),
              
              const SizedBox(height: 16),
              
              // News section
              _buildNewsCard(news),
              
              const SizedBox(height: 16),
              
              // Stocks section
              _buildStocksCard(stocks),
              
              const SizedBox(height: 16),
              
              // Instructions
              _buildInstructionsCard(),
            ],
          ),
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
                  isInForeground ? Icons.smartphone : Icons.phone_android,
                  color: isInForeground ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'App Lifecycle Status',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow('Current State', appState.name.toUpperCase(), 
                isInForeground ? Colors.green : Colors.orange),
            _buildStatusRow('Query Behavior', 
                isInForeground ? 'ACTIVE REFETCHING' : 'PAUSED REFETCHING', 
                isInForeground ? Colors.green : Colors.orange),
            _buildStatusRow('Background Count', _backgroundCount.toString(), Colors.red),
            _buildStatusRow('Foreground Count', _foregroundCount.toString(), Colors.blue),
            
            if (_lastBackgroundTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last went to background: ${_formatTime(_lastBackgroundTime!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            if (_lastForegroundTime != null) ...[
              Text(
                'Last came to foreground: ${_formatTime(_lastForegroundTime!)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherCard(QueryState<Map<String, dynamic>> weather) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_sunny, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Current Weather',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (weather is QueryRefetching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            weather.when(
              idle: () => const Text('Ready to load weather'),
              loading: () => const Center(child: CircularProgressIndicator()),
              success: (data) => _buildWeatherContent(data),
              error: (error, _) => Text('Error: $error', style: const TextStyle(color: Colors.red)),
              refetching: (previousData) => _buildWeatherContent(previousData),
            ) ?? const Text('Unknown state'),
            const SizedBox(height: 8),
            Text(
              '⏰ Updates every 2 minutes (when app is active)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherContent(Map<String, dynamic> data) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${data['temperature']}°C',
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              Text(
                data['condition'],
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Humidity: ${data['humidity']}%'),
              Text('Wind: ${data['wind_speed']} km/h'),
              Text('Updates: ${data['request_count']}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNewsCard(QueryState<List<Map<String, dynamic>>> news) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.newspaper, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Breaking News',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (news is QueryRefetching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            news.when(
              idle: () => const Text('Ready to load news'),
              loading: () => const Center(child: CircularProgressIndicator()),
              success: (articles) => _buildNewsList(articles),
              error: (error, _) => Text('Error: $error', style: const TextStyle(color: Colors.red)),
              refetching: (previousArticles) => _buildNewsList(previousArticles),
            ) ?? const Text('Unknown state'),
            const SizedBox(height: 8),
            Text(
              '⚡ Updates every 30 seconds (paused in background)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewsList(List<Map<String, dynamic>> articles) {
    return Column(
      children: articles.map((article) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article['headline'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      article['category'],
                      style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(DateTime.parse(article['timestamp'])),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStocksCard(QueryState<List<Map<String, dynamic>>> stocks) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Stock Prices',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (stocks is QueryRefetching)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            stocks.when(
              idle: () => const Text('Ready to load stocks'),
              loading: () => const Center(child: CircularProgressIndicator()),
              success: (stockList) => _buildStocksList(stockList),
              error: (error, _) => Text('Error: $error', style: const TextStyle(color: Colors.red)),
              refetching: (previousStocks) => _buildStocksList(previousStocks),
            ) ?? const Text('Unknown state'),
            const SizedBox(height: 8),
            Text(
              '🚀 Updates every 10 seconds (real-time when active)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStocksList(List<Map<String, dynamic>> stockList) {
    return Column(
      children: stockList.map((stock) {
        final change = stock['change'] as int;
        final isPositive = change >= 0;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isPositive ? Colors.green[50] : Colors.red[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isPositive ? Colors.green[200]! : Colors.red[200]!,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  stock['symbol'],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  '\$${stock['price']}',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 16,
                      color: isPositive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isPositive ? '+' : ''}${stock['change_percent']}%',
                      style: TextStyle(
                        color: isPositive ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
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
      color: Colors.purple[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info, color: Colors.purple[700]),
                const SizedBox(width: 8),
                Text(
                  'How to Test Background/Foreground',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInstructionPoint(
              '📱 Switch Apps',
              'Press home button or switch to another app to put this app in background',
            ),
            _buildInstructionPoint(
              '⏰ Wait & Observe',
              'Notice how the app state changes to "PAUSED" and queries stop refetching',
            ),
            _buildInstructionPoint(
              '🔄 Return to App',
              'Switch back to this app and see it automatically refetch stale data',
            ),
            _buildInstructionPoint(
              '📊 Check Counters',
              'Background/Foreground counters show how many times you\'ve switched',
            ),
            _buildInstructionPoint(
              '🔄 Pull to Refresh',
              'You can also manually refresh all data by pulling down',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '💡 This demonstrates real-world scenarios like news apps, weather apps, '
                'and trading apps that need fresh data when active but should save battery in background.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.purple[800],
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
              color: Colors.purple[700],
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

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }
}

// Usage in main app
class BackgroundForegroundDemo extends StatelessWidget {
  const BackgroundForegroundDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'Background/Foreground Demo',
        theme: ThemeData(primarySwatch: Colors.green),
        home: const BackgroundForegroundExample(),
      ),
    );
  }
}
