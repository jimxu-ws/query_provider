# Riverpod 集成指南

本指南展示如何让现有的 `@riverpod` 注解生成的 provider 具备 QueryProvider 的所有能力，包括缓存、重试、乐观更新等功能。

## 核心概念

通过扩展方法和工具类，你可以在保持 `@riverpod` 语法的同时，获得：
- ✅ 自动缓存和状态管理
- ✅ 智能重试机制
- ✅ 乐观更新和错误回滚
- ✅ 缓存失效和数据同步
- ✅ 网络状态感知
- ✅ 完整的 TypeScript 类型支持

## 使用方法

### 1. 查询 Provider (Query)

使用 `ref.asQuery()` 扩展方法为任何 `@riverpod` provider 添加查询能力：

```dart
@riverpod
Future<List<User>> users(UsersRef ref) async {
  return ref.asQuery(
    queryFn: () => ApiService.fetchUsers(),
    queryKey: 'users',
    options: const QueryOptions<List<User>>(
      staleTime: Duration(minutes: 5),    // 数据保鲜时间
      cacheTime: Duration(minutes: 10),   // 缓存保留时间
      refetchOnMount: true,               // 挂载时重新获取
      retry: 3,                          // 重试次数
    ),
  );
}

// 带参数的查询
@riverpod
Future<User> user(UserRef ref, int userId) async {
  return ref.asQuery(
    queryFn: () => ApiService.fetchUser(userId),
    queryKey: 'user-$userId',
    options: const QueryOptions<User>(
      staleTime: Duration(minutes: 3),
      cacheTime: Duration(minutes: 15),
    ),
  );
}
```

### 2. 变更 Provider (Mutation)

使用 `ref.asMutation()` 扩展方法为创建、更新、删除操作添加变更能力：

```dart
@riverpod
Future<User> createUser(CreateUserRef ref, Map<String, dynamic> userData) async {
  final mutationFn = ref.asMutation<User, Map<String, dynamic>>(
    mutationFn: (data) => ApiService.createUser(data),
    options: MutationOptions<User, Map<String, dynamic>>(
      // 乐观更新：立即更新 UI
      onMutate: (variables) async {
        final queryClient = ref.read(queryClientProvider);
        final currentUsers = queryClient.getQueryData<List<User>>('users');
        if (currentUsers != null) {
          final newUser = User(
            id: DateTime.now().millisecondsSinceEpoch, // 临时 ID
            name: variables['name'] as String,
            email: variables['email'] as String,
          );
          queryClient.setQueryData<List<User>>('users', [...currentUsers, newUser]);
        }
      },
      // 成功回调：使缓存失效获取最新数据
      onSuccess: (user, variables) async {
        final queryClient = ref.read(queryClientProvider);
        queryClient.invalidateQueries('users');
      },
      // 错误回调：回滚乐观更新
      onError: (error, variables, stackTrace) async {
        final queryClient = ref.read(queryClientProvider);
        queryClient.invalidateQueries('users');
      },
      retry: 2,
      retryDelay: const Duration(seconds: 1),
    ),
  );
  
  return mutationFn(userData);
}
```

### 3. 无限查询 Provider (Infinite Query)

使用 `ref.asInfiniteQuery()` 扩展方法实现分页加载：

```dart
@riverpod
Future<List<PostPage>> infinitePosts(InfinitePostsRef ref) async {
  return ref.asInfiniteQuery<PostPage, int>(
    queryFn: (pageParam) => ApiService.fetchPostsPage(page: pageParam),
    initialPageParam: 1,
    getNextPageParam: (lastPage, allPages) {
      return lastPage.hasMore ? allPages.length + 1 : null;
    },
    queryKey: 'posts-infinite',
    options: const InfiniteQueryOptions<PostPage>(
      staleTime: Duration(minutes: 2),
      cacheTime: Duration(minutes: 10),
    ),
  );
}
```

## 工具类方法

### QueryUtils

如果你不想使用扩展方法，也可以使用 `QueryUtils` 工具类：

```dart
// 简单查询
final usersProvider = QueryUtils.query<List<User>>(
  name: 'users',
  queryFn: () => ApiService.fetchUsers(),
  options: const QueryOptions<List<User>>(
    staleTime: Duration(minutes: 5),
  ),
);

// 简单变更
final createUserProvider = QueryUtils.mutation<User, Map<String, dynamic>>(
  name: 'create-user',
  mutationFn: (userData) => ApiService.createUser(userData),
  options: MutationOptions<User, Map<String, dynamic>>(
    retry: 2,
    onSuccess: (user, _) => print('User ${user.name} created!'),
  ),
);
```

### QueryCapabilities Mixin

为自定义 StateNotifier 添加查询能力：

```dart
class PostsNotifier extends StateNotifier<List<Post>> with QueryCapabilities<List<Post>> {
  PostsNotifier() : super([]);

  Future<void> loadPosts() async {
    try {
      final posts = await executeQuery<List<Post>>(
        queryKey: 'posts-custom',
        queryFn: () => ApiService.fetchPosts(),
        options: const QueryOptions<List<Post>>(
          staleTime: Duration(minutes: 5),
          retry: 3,
        ),
      );
      state = posts;
    } catch (error) {
      // 处理错误
    }
  }

  Future<void> createPost(Map<String, dynamic> postData) async {
    try {
      final newPost = await ApiService.createPost(postData);
      state = [...state, newPost];
      
      // 使相关查询失效
      invalidateQueries('posts');
    } catch (error) {
      // 处理错误
    }
  }
}
```

## UI 中的使用

在 UI 中使用这些 provider 就像使用普通的 `@riverpod` provider 一样：

```dart
class UsersScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 自动缓存、重试、状态管理
    final usersAsync = ref.watch(usersProvider);

    return usersAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (error, stack) => Column(
        children: [
          Text('Error: $error'),
          ElevatedButton(
            // 重新获取数据
            onPressed: () => ref.invalidate(usersProvider),
            child: const Text('Retry'),
          ),
        ],
      ),
      data: (users) => RefreshIndicator(
        // 下拉刷新
        onRefresh: () => ref.refresh(usersProvider.future),
        child: ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) => UserTile(user: users[index]),
        ),
      ),
    );
  }
}

// 创建用户
class CreateUserButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () async {
        try {
          // 自动乐观更新和错误回滚
          await ref.read(createUserProvider({
            'name': 'John Doe',
            'email': 'john@example.com',
          }).future);
          
          // 成功提示
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User created!')),
          );
        } catch (e) {
          // 错误处理
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      },
      child: const Text('Create User'),
    );
  }
}
```

## 主要优势

### 1. 保持 Riverpod 语法
- 继续使用熟悉的 `@riverpod` 注解
- 无需学习新的 API
- 完整的代码生成支持

### 2. 增强功能
- **智能缓存**: 自动缓存数据，减少网络请求
- **重试机制**: 网络失败时自动重试
- **乐观更新**: 立即更新 UI，提升用户体验
- **错误回滚**: 失败时自动恢复之前的状态
- **缓存同步**: 多个组件间自动同步数据

### 3. 类型安全
- 完整的 TypeScript 类型支持
- 编译时错误检查
- IntelliSense 自动补全

### 4. 性能优化
- 智能缓存策略
- 减少不必要的网络请求
- 内存管理优化

## 最佳实践

### 1. 查询键命名
```dart
// 好的命名
'users'
'user-123'
'posts-by-user-456'

// 避免
'data'
'info'
'temp'
```

### 2. 缓存时间设置
```dart
// 频繁变化的数据
staleTime: Duration(seconds: 30)

// 相对稳定的数据
staleTime: Duration(minutes: 5)

// 很少变化的数据
staleTime: Duration(hours: 1)
```

### 3. 错误处理
```dart
options: MutationOptions(
  onError: (error, variables, stackTrace) async {
    // 记录错误
    logger.error('Mutation failed', error, stackTrace);
    
    // 回滚乐观更新
    queryClient.invalidateQueries('users');
    
    // 显示用户友好的错误信息
    showErrorDialog(error);
  },
),
```

这种方式让你可以在保持现有 Riverpod 代码结构的同时，获得 React Query 级别的数据管理能力！
