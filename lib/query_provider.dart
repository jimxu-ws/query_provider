/// A React Query-like data fetching library for Flutter using Riverpod
library query_provider;

// Re-export Riverpod types for convenience
export 'package:flutter_riverpod/flutter_riverpod.dart' show StateNotifierProviderFamily;

export 'src/app_lifecycle_manager.dart';
export 'src/async_query_provider.dart';
export 'src/extensions/query_extensions.dart';
export 'src/extensions/riverpod_extensions.dart';
export 'src/hooks/query_hooks.dart';
export 'src/infinite_query_provider.dart';
export 'src/mutation_options.dart';
export 'src/mutation_provider.dart';
export 'src/query_cache.dart';
export 'src/query_client.dart';
export 'src/query_options.dart';
export 'src/query_provider.dart';
export 'src/query_state.dart';
export 'src/window_focus_manager.dart';
