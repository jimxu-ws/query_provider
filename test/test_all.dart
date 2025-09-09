import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'query_state_test.dart' as query_state_test;
import 'query_options_test.dart' as query_options_test;
import 'query_cache_test.dart' as query_cache_test;
import 'app_lifecycle_manager_test.dart' as app_lifecycle_manager_test;
import 'window_focus_manager_test.dart' as window_focus_manager_test;
import 'query_provider_test.dart' as query_provider_test;
import 'mutation_provider_test.dart' as mutation_provider_test;

void main() {
  group('Query Provider Library Tests', () {
    group('Query State Tests', query_state_test.main);
    group('Query Options Tests', query_options_test.main);
    group('Query Cache Tests', query_cache_test.main);
    group('App Lifecycle Manager Tests', app_lifecycle_manager_test.main);
    group('Window Focus Manager Tests', window_focus_manager_test.main);
    group('Query Provider Tests', query_provider_test.main);
    group('Mutation Provider Tests', mutation_provider_test.main);
  });
}
