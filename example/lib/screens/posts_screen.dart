import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:query_provider/query_provider.dart';

import '../providers/post_providers.dart';
import '../models/post.dart';

class PostsScreen extends ConsumerWidget {
  const PostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final infiniteQuery = ref.readInfiniteQueryResult(postsInfiniteQueryProvider);//postsInfiniteQueryProvider.use(ref);

    return infiniteQuery.state.when(
      idle: () => const Center(child: Text('Loading posts...')),
      loading: () => const Center(child: CircularProgressIndicator()),
      success: (pages, hasNextPage, hasPreviousPage, fetchedAt) => PostsList(
        pages: pages,
        hasNextPage: hasNextPage,
        isFetchingNextPage: infiniteQuery.isFetchingNextPage,
        onLoadMore: infiniteQuery.fetchNextPage,
        onRefresh: infiniteQuery.refetch,
      ),
      error: (error, stackTrace) => ErrorView(
        error: error,
        onRetry: infiniteQuery.refetch,
      ),
      fetchingNextPage: (pages, hasNextPage, hasPreviousPage, fetchedAt) => PostsList(
        pages: pages,
        hasNextPage: hasNextPage,
        isFetchingNextPage: true,
        onLoadMore: infiniteQuery.fetchNextPage,
        onRefresh: infiniteQuery.refetch,
      ),
      fetchingPreviousPage: (pages, hasNextPage, hasPreviousPage, fetchedAt) => PostsList(
        pages: pages,
        hasNextPage: hasNextPage,
        isFetchingNextPage: false,
        onLoadMore: infiniteQuery.fetchNextPage,
        onRefresh: infiniteQuery.refetch,
      ),
    );
  }
}

class PostsList extends StatefulWidget {
  const PostsList({
    super.key,
    required this.pages,
    required this.hasNextPage,
    required this.isFetchingNextPage,
    required this.onLoadMore,
    required this.onRefresh,
  });

  final List<PostPage> pages;
  final bool hasNextPage;
  final bool isFetchingNextPage;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRefresh;

  @override
  State<PostsList> createState() => _PostsListState();
}

class _PostsListState extends State<PostsList> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      // Load more when user is 200 pixels from the bottom
      _loadMoreIfNeeded();
    }
  }

  Future<void> _loadMoreIfNeeded() async {
    if (widget.hasNextPage && !widget.isFetchingNextPage && !_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
      });
      
      try {
        await widget.onLoadMore();
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingMore = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Flatten all posts from all pages
    final allPosts = widget.pages.expand((page) => page.posts).toList();

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        itemCount: allPosts.length + (widget.hasNextPage || widget.isFetchingNextPage ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == allPosts.length) {
            // Auto-loading indicator
            return AutoLoadingIndicator(
              isLoading: widget.isFetchingNextPage || _isLoadingMore,
            );
          }

          final post = allPosts[index];
          return PostListTile(post: post);
        },
      ),
    );
  }
}

class PostListTile extends StatelessWidget {
  const PostListTile({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        title: Text(
          post.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              post.body,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'By User ${post.userId} • Post #${post.id}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        isThreeLine: true,
        onTap: () {
          _showPostDetails(context, post);
        },
      ),
    );
  }

  void _showPostDetails(BuildContext context, Post post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(post.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(post.body),
              const SizedBox(height: 16),
              Text(
                'Post ID: ${post.id}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                'Author: User ${post.userId}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class AutoLoadingIndicator extends StatelessWidget {
  const AutoLoadingIndicator({
    super.key,
    required this.isLoading,
  });

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (!isLoading) {
      // Return a small invisible widget when not loading
      return const SizedBox(height: 16);
    }

    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text(
              'Loading more posts...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading posts',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// Extension to handle infinite query state more elegantly
extension InfiniteQueryStateExtension<T> on InfiniteQueryState<T> {
  R when<R>({
    required R Function() idle,
    required R Function() loading,
    required R Function(List<T> pages, bool hasNextPage, bool hasPreviousPage, DateTime? fetchedAt) success,
    required R Function(Object error, StackTrace? stackTrace) error,
    required R Function(List<T> pages, bool hasNextPage, bool hasPreviousPage, DateTime? fetchedAt) fetchingNextPage,
    required R Function(List<T> pages, bool hasNextPage, bool hasPreviousPage, DateTime? fetchedAt) fetchingPreviousPage,
  }) {
    return switch (this) {
      InfiniteQueryIdle<T>() => idle(),
      InfiniteQueryLoading<T>() => loading(),
      InfiniteQuerySuccess<T> successState => success(successState.pages, successState.hasNextPage, successState.hasPreviousPage, successState.fetchedAt),
      InfiniteQueryError<T> errorState => error(errorState.error, errorState.stackTrace),
      InfiniteQueryFetchingNextPage<T> fetching => fetchingNextPage(fetching.pages, fetching.hasNextPage, fetching.hasPreviousPage, fetching.fetchedAt),
      InfiniteQueryFetchingPreviousPage<T> fetching => fetchingPreviousPage(fetching.pages, fetching.hasNextPage, fetching.hasPreviousPage, fetching.fetchedAt),
    };
  }
}
