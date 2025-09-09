# @riverpod + QueryProvider 集成方案

## 概述

这个集成方案让你可以在保持现有 `@riverpod` 注解语法的同时，获得 QueryProvider 的所有强大功能：缓存、乐观更新、重试机制、状态管理等。

## 核心功能

### 1. 扩展方法 (RiverpodQueryExtensions)

为所有 `Ref` 对象添加 QueryProvider 能力：

```dart
@riverpod
Future<User> createUser(CreateUserRef ref, Map<String, dynamic> userData) async {
  // 乐观更新
  final currentUsers = ref.getQueryData<List<User>>('users');
  if (currentUsers != null) {
    ref.setQueryData('users', [...currentUsers, optimisticUser]);
  }

  try {
    final result = await ApiService.createUser(userData);
    ref.invalidateQueries('users');  // 使缓存失效
    return result;
  } catch (error) {
    ref.invalidateQueries('users');  // 回滚
    rethrow;
  }
}
```

### 2. 工具类 (QueryUtils)

简化 provider 创建：

```dart
// 查询 provider
final usersProvider = QueryUtils.query<List<User>>(
  name: 'users',
  queryFn: () => ApiService.fetchUsers(),
  options: QueryOptions(staleTime: Duration(minutes: 5)),
);

// 变更 provider
final createUserProvider = QueryUtils.mutation<User, Map<String, dynamic>>(
  name: 'create-user',
  mutationFn: (userData) => ApiService.createUser(userData),
  options: MutationOptions(
    onSuccess: (user, _) => print('User created!'),
  ),
);
```

### 3. Mixin (QueryCapabilities)

为自定义 StateNotifier 添加查询能力：

```dart
class PostsNotifier extends StateNotifier<List<Post>> with QueryCapabilities<List<Post>> {
  Future<void> loadPosts() async {
    final posts = await executeQuery(
      queryKey: 'posts',
      queryFn: () => ApiService.fetchPosts(),
    );
    state = posts;
  }
}
```

## 主要优势

### ✅ 保持 Riverpod 语法
- 继续使用 `@riverpod` 注解
- 无需学习新的 API
- 完整的代码生成支持

### ✅ 增强功能
- **乐观更新**: 立即更新 UI，提升用户体验
- **智能缓存**: 自动缓存数据，减少网络请求
- **错误回滚**: 失败时自动恢复之前的状态
- **缓存同步**: 多个组件间自动同步数据

### ✅ 简单集成
- 只需添加几个扩展方法
- 现有代码无需大幅修改
- 渐进式采用

## 实际使用示例

### 1. 基础查询 + 缓存

```dart
@riverpod
Future<List<User>> users(UsersRef ref) async {
  // 直接调用 API，QueryUtils.query 已处理缓存
  return ApiService.fetchUsers();
}

// 或使用 QueryUtils 创建带缓存的 provider
final usersProvider = QueryUtils.query<List<User>>(
  name: 'users',
  queryFn: () => ApiService.fetchUsers(),
  options: QueryOptions(staleTime: Duration(minutes: 5)),
);
```

### 2. 乐观更新的变更操作

```dart
@riverpod
Future<User> createUser(CreateUserRef ref, Map<String, dynamic> userData) async {
  // 1. 乐观更新 - 立即更新 UI
  final currentUsers = ref.getQueryData<List<User>>('users');
  if (currentUsers != null) {
    final optimisticUser = User(/* ... */);
    ref.setQueryData<List<User>>('users', [...currentUsers, optimisticUser]);
  }

  try {
    // 2. 执行实际操作
    final result = await ApiService.createUser(userData);
    
    // 3. 成功后使缓存失效获取最新数据
    ref.invalidateQueries('users');
    
    return result;
  } catch (error) {
    // 4. 失败时回滚乐观更新
    ref.invalidateQueries('users');
    rethrow;
  }
}
```

### 3. 智能数据获取

```dart
@riverpod
Future<List<Post>> userPosts(UserPostsRef ref, int userId) async {
  // 首先检查是否有缓存的全部帖子
  final cachedPosts = ref.getQueryData<List<Post>>('posts');
  if (cachedPosts != null) {
    return cachedPosts.where((post) => post.userId == userId).toList();
  }

  // 没有缓存时才从 API 获取
  return ApiService.fetchUserPosts(userId);
}
```

### 4. 批量操作

```dart
@riverpod
Future<void> batchUpdatePosts(BatchUpdatePostsRef ref, List<Update> updates) async {
  try {
    for (final update in updates) {
      await ApiService.updatePost(update.id, update.data);
    }
    
    // 批量操作完成后使相关缓存失效
    ref.invalidateQueries('posts');
    ref.invalidateQueries('user-posts');
  } catch (error) {
    ref.invalidateQueries('posts');  // 确保数据一致性
    rethrow;
  }
}
```

## UI 中的使用

使用方式与普通 `@riverpod` provider 完全相同：

```dart
class UsersScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 自动获得缓存、重试、状态管理等功能
    final usersAsync = ref.watch(usersProvider);

    return usersAsync.when(
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error),
      data: (users) => ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) => UserTile(user: users[index]),
      ),
    );
  }
}

// 创建用户按钮
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
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('User created!')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      },
      child: Text('Create User'),
    );
  }
}
```

## 最佳实践

### 1. 缓存键命名规范
```dart
'users'              // 所有用户
'user-123'           // 特定用户
'posts'              // 所有帖子
'user-posts-456'     // 特定用户的帖子
'search-results-abc' // 搜索结果
```

### 2. 乐观更新模式
```dart
// 1. 保存当前状态（可选）
final currentData = ref.getQueryData<T>(key);

// 2. 乐观更新
ref.setQueryData<T>(key, optimisticData);

try {
  // 3. 执行操作
  final result = await apiCall();
  
  // 4. 成功后使缓存失效或设置真实数据
  ref.invalidateQueries(key);
} catch (error) {
  // 5. 失败时回滚
  ref.invalidateQueries(key);
  rethrow;
}
```

### 3. 错误处理
```dart
@riverpod
Future<T> riskyOperation(RiskyOperationRef ref, Data data) async {
  try {
    return await ApiService.riskyCall(data);
  } catch (error) {
    // 记录错误
    logger.error('Operation failed', error);
    
    // 清理相关缓存
    ref.invalidateQueries('related-data');
    
    // 重新抛出错误让 UI 处理
    rethrow;
  }
}
```

## 总结

这个集成方案让你可以：

1. **保持现有代码结构** - 继续使用 `@riverpod` 注解
2. **获得强大功能** - 缓存、乐观更新、错误处理
3. **提升用户体验** - 即时 UI 反馈、智能数据管理
4. **简化开发** - 减少样板代码、自动状态管理

通过这种方式，你可以在不改变现有开发习惯的情况下，获得 React Query 级别的数据管理能力！
