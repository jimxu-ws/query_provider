import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:query_provider/query_provider.dart';
import '../models/user.dart';
import '../services/api_service.dart';

/// 🎯 SmartCachedFetcher 示例 - 使用 StateNotifier (推荐方式)
class UserProfileNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref ref;
  final int userId;
  // 🔥 SmartCachedFetcher - 智能缓存获取器
  late final SmartCachedFetcher<User> _userFetcher;
  
  UserProfileNotifier(this.ref, this.userId) : super(const AsyncValue.loading()) {
    // 🚀 初始化智能缓存获取器
    _userFetcher = ref.cachedFetcher<User>(
      fetchFn: () => ApiService.fetchUser(userId),
      cacheKey: 'user-$userId',
      onData: (user) {
        // 📡 数据获取成功回调
        state = AsyncValue.data(user);
        debugPrint('✅ User data updated: ${user.name}');
      },
      onLoading: () {
        // ⏳ 加载开始回调 - 只在没有数据时显示loading
        if (!state.hasValue) {
          state = const AsyncValue.loading();
        }
        debugPrint('⏳ Loading user $userId...');
      },
      onError: (error) {
        // ❌ 错误处理回调
        state = AsyncValue.error(error, StackTrace.current);
        debugPrint('❌ Failed to load user $userId: $error');
      },
      // 🔧 配置选项
      staleTime: const Duration(minutes: 5),     // 5分钟内数据不过期
      cacheTime: const Duration(minutes: 30),   // 缓存保持30分钟
      enableBackgroundRefresh: true,            // 启用后台刷新
      enableWindowFocusRefresh: true,           // 启用窗口聚焦刷新
      cacheErrors: false,                       // 不缓存错误
    );
    
    // 🎯 初始化时检查缓存
    _initializeFromCache();
  }
  
  /// 从缓存初始化状态
  void _initializeFromCache() {
    final cachedUser = _userFetcher.getCached();
    if (cachedUser != null) {
      state = AsyncValue.data(cachedUser);
      debugPrint('✅ Initialized from cache: ${cachedUser.name}');
    } else {
      state = const AsyncValue.data(null);
    }
  }
  
  /// 🎯 获取用户数据 - 智能缓存策略
  Future<void> fetchUser() async {
    await _userFetcher.fetch();
  }
  
  /// 🔄 强制刷新用户数据
  Future<void> refreshUser() async {
    await _userFetcher.refresh();
  }
  
  /// 🗑️ 清除缓存
  void clearCache() {
    _userFetcher.clearCache();
    state = const AsyncValue.data(null);
  }
  
  /// 📊 获取缓存状态
  bool get isCached => _userFetcher.isCached;
  bool get isStale => _userFetcher.isStale;
  bool get isFetching => _userFetcher.isFetching;
  User? get cachedData => _userFetcher.getCached();
}

/// 🎯 UserProfile Provider - StateNotifierProvider.family 方式
final userProfileProvider = StateNotifierProvider.family<UserProfileNotifier, AsyncValue<User?>, int>((ref, userId) {
  return UserProfileNotifier(ref, userId);
});

/// 🎯 SmartCachedFetcher 示例页面
class SmartCachedFetcherExample extends ConsumerWidget {
  final int userId;
  
  const SmartCachedFetcherExample({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(userProfileProvider(userId));
    final userNotifier = ref.read(userProfileProvider(userId).notifier);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('SmartCachedFetcher 示例'),
        backgroundColor: Colors.blue.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📊 缓存状态显示
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('缓存状态', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('是否有缓存: ${userNotifier.isCached}'),
                    Text('数据是否过期: ${userNotifier.isStale}'),
                    Text('正在获取: ${userNotifier.isFetching}'),
                    if (userNotifier.cachedData != null)
                      Text('缓存数据: ${userNotifier.cachedData!.name}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 🎯 用户数据显示
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: userState.when(
                    data: (user) => user == null 
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_outline, size: 64),
                                SizedBox(height: 16),
                                Text('点击按钮获取用户数据'),
                              ],
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      user.name,
                                      style: Theme.of(context).textTheme.headlineSmall,
                                    ),
                                  ),
                                  if (userNotifier.isStale)
                                    Chip(
                                      label: const Text('数据已过期'),
                                      backgroundColor: Colors.orange.shade100,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('Email: ${user.email}'),
                              Text('用户ID: ${user.id}'),
                              if (user.avatar != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  '头像信息',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text('头像URL: ${user.avatar}'),
                              ],
                            ],
                          ),
                    loading: () => const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('正在加载用户数据...'),
                        ],
                      ),
                    ),
                    error: (error, stack) => Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                          const SizedBox(height: 16),
                          Text('加载失败: $error'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => userNotifier.fetchUser(),
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 🎮 操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => userNotifier.fetchUser(),
                    icon: const Icon(Icons.download),
                    label: const Text('获取数据'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => userNotifier.refreshUser(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('强制刷新'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => userNotifier.clearCache(),
                    icon: const Icon(Icons.clear),
                    label: const Text('清除缓存'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 🎯 useSmartQuery Hook 示例页面
class UseSmartQueryExample extends HookConsumerWidget {
  final int userId;
  
  const UseSmartQueryExample({
    super.key,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔥 使用 useSmartQuery Hook
    final userQuery = useSmartQuery<User>(
      ref: ref,
      fetchFn: () => ApiService.fetchUser(userId),
      cacheKey: 'user-hook-$userId',
      staleTime: const Duration(minutes: 5),
      cacheTime: const Duration(minutes: 30),
      enableBackgroundRefresh: true,
      enableWindowFocusRefresh: true,
      cacheErrors: false,
    );
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('useSmartQuery Hook 示例'),
        backgroundColor: Colors.green.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 📊 Hook 状态显示
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hook 状态', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text('是否有缓存: ${userQuery.isCached}'),
                    Text('数据是否过期: ${userQuery.isStale}'),
                    Text('正在获取: ${userQuery.isFetching}'),
                    Text('是否有数据: ${userQuery.data != null}'),
                    Text('是否有错误: ${userQuery.error != null}'),
                    if (userQuery.error != null)
                      Text('错误信息: ${userQuery.error}', 
                           style: TextStyle(color: Colors.red.shade700)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 🎯 用户数据显示
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: userQuery.data == null
                      ? Center(
                          child: userQuery.isFetching
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('正在加载用户数据...'),
                                  ],
                                )
                              : userQuery.error != null
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.error_outline, 
                                             size: 64, 
                                             color: Colors.red.shade400),
                                        const SizedBox(height: 16),
                                        Text('加载失败: ${userQuery.error}'),
                                      ],
                                    )
                                  : const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.person_outline, size: 64),
                                        SizedBox(height: 16),
                                        Text('点击按钮获取用户数据'),
                                      ],
                                    ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    userQuery.data!.name,
                                    style: Theme.of(context).textTheme.headlineSmall,
                                  ),
                                ),
                                if (userQuery.isStale)
                                  Chip(
                                    label: const Text('数据已过期'),
                                    backgroundColor: Colors.orange.shade100,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Email: ${userQuery.data!.email}'),
                            Text('用户ID: ${userQuery.data!.id}'),
                            if (userQuery.data!.avatar != null) ...[
                              const SizedBox(height: 16),
                              Text(
                                '头像信息',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text('头像URL: ${userQuery.data!.avatar}'),
                            ],
                          ],
                        ),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // 🎮 操作按钮
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => userQuery.refetch(),
                    icon: const Icon(Icons.download),
                    label: const Text('获取数据'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => userQuery.refresh(),
                    icon: const Icon(Icons.refresh),
                    label: const Text('强制刷新'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => userQuery.clearCache(),
                    icon: const Icon(Icons.clear),
                    label: const Text('清除缓存'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 🎯 对比示例页面
class SmartCacheComparisonScreen extends StatelessWidget {
  const SmartCacheComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('智能缓存示例对比'),
          bottom: const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.code),
                text: 'SmartCachedFetcher',
              ),
              Tab(
                icon: Icon(Icons.api),
                text: 'useSmartQuery Hook',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            SmartCachedFetcherExample(userId: 1),
            UseSmartQueryExample(userId: 1),
          ],
        ),
      ),
    );
  }
}
