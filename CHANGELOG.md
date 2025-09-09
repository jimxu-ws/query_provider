# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-XX

### Added
- Initial release of Query Provider
- `QueryProvider` for basic data fetching with caching
- `MutationProvider` for data mutations
- `InfiniteQueryProvider` for paginated data
- Comprehensive query state management (idle, loading, success, error, refetching)
- Configurable caching with stale time and cache time
- Automatic retry logic with configurable attempts and delays
- Background refetching capabilities
- Query invalidation and cache management
- Type-safe API with full Dart generics support
- Integration with Riverpod for state management
- Extensive documentation and examples
- Complete example application demonstrating all features

### Features
- ✅ Declarative data fetching API
- ✅ Intelligent caching system
- ✅ Background updates and refetching
- ✅ Optimistic updates support
- ✅ Built-in retry mechanisms
- ✅ Infinite query support for pagination
- ✅ Mutation handling with lifecycle callbacks
- ✅ Flexible configuration options
- ✅ Type safety with generics
- ✅ Riverpod integration
- ✅ Query client for global operations
- ✅ Extension methods for convenience
- ✅ Comprehensive error handling
- ✅ Performance optimizations
