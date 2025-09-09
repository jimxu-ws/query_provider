# UI Invalidation Example

This example demonstrates how UI invalidation works when creating, updating, and deleting users in the Query Provider system.

## What's Been Implemented

### 1. Enhanced User Mutation Providers

All user mutation providers (`createUserMutationProvider`, `updateUserMutationProvider`, `deleteUserMutationProvider`) now include:

- **Optimistic Updates**: UI updates immediately when mutations are triggered
- **Cache Invalidation**: Queries are invalidated to ensure fresh data from server
- **Error Rollback**: Failed mutations rollback optimistic updates

### 2. Complete CRUD Operations

#### Create User
- **Location**: `MutationsTab` in `home_screen.dart`
- **Optimistic Update**: Adds new user to cache with temporary ID
- **On Success**: Invalidates `users` and `userSearch` queries
- **On Error**: Rolls back by invalidating `users` query

#### Delete User  
- **Location**: Delete button on each user in `UsersTab`
- **Optimistic Update**: Removes user from cache immediately
- **On Success**: Invalidates `users` and `userSearch` queries, removes individual user cache
- **On Error**: Rolls back by invalidating `users` query

#### Update User
- **Location**: Available via `updateUserMutationProvider(userId)` 
- **Optimistic Update**: Updates user in both `users` list and individual `user-$userId` cache
- **On Success**: Invalidates `users`, `user-$userId`, and `userSearch` queries
- **On Error**: Rolls back by invalidating relevant queries

## How UI Invalidation Works

### 1. Optimistic Updates
When a mutation is triggered, the cache is updated immediately using `queryClient.setQueryData()`. This causes the UI to update instantly without waiting for the server response.

### 2. Cache Listening
The `QueryNotifier` and `InfiniteQueryNotifier` automatically listen for cache changes and update their state when the cache is modified externally.

### 3. Success/Error Handling
- **On Success**: Queries are invalidated to refetch fresh data from the server
- **On Error**: The cache is invalidated to rollback optimistic updates

## Testing the Example

1. **Create a User**: 
   - Go to the "Mutations" tab
   - Fill in name and email
   - Click "Create User"
   - Notice the user appears immediately in the "Users" tab (optimistic update)

2. **Delete a User**:
   - Go to the "Users" tab  
   - Click the red delete button on any user
   - Confirm deletion
   - Notice the user disappears immediately (optimistic update)

3. **UI Consistency**:
   - The UI stays consistent across all tabs
   - Search results are also invalidated when users are modified
   - Individual user detail pages are updated when users are modified

## Key Benefits

- **Instant UI Feedback**: Users see changes immediately
- **Network Efficiency**: Reduces unnecessary refetches
- **Error Resilience**: Failed mutations are rolled back gracefully
- **Cache Consistency**: All related queries stay in sync
