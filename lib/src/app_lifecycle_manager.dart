import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages app lifecycle state and window focus for query refetching
class AppLifecycleManager extends ChangeNotifier with WidgetsBindingObserver {
  static AppLifecycleManager? _instance;
  
  /// Singleton instance
  static AppLifecycleManager get instance {
    _instance ??= AppLifecycleManager._();
    return _instance!;
  }
  
  AppLifecycleManager._() {
    WidgetsBinding.instance.addObserver(this);
  }
  
  AppLifecycleState _state = AppLifecycleState.resumed;
  bool _windowHasFocus = true;
  final Set<VoidCallback> _onResumeCallbacks = {};
  final Set<VoidCallback> _onPauseCallbacks = {};
  final Set<VoidCallback> _onWindowFocusCallbacks = {};
  final Set<VoidCallback> _onWindowBlurCallbacks = {};
  
  /// Current app lifecycle state
  AppLifecycleState get state => _state;
  
  /// Whether the app is currently in foreground
  bool get isInForeground => _state == AppLifecycleState.resumed;
  
  /// Whether the app is currently in background
  bool get isInBackground => !isInForeground;
  
  /// Whether the window currently has focus
  bool get windowHasFocus => _windowHasFocus;
  
  /// Whether the window has lost focus
  bool get windowHasLostFocus => !_windowHasFocus;
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final previousState = _state;
    _state = state;
    
    // Notify listeners of state change
    notifyListeners();
    
    // Handle transitions
    if (previousState != AppLifecycleState.resumed && 
        state == AppLifecycleState.resumed) {
      // App came to foreground
      _notifyResumeCallbacks();
    } else if (previousState == AppLifecycleState.resumed && 
               state != AppLifecycleState.resumed) {
      // App went to background
      _notifyPauseCallbacks();
    }
  }
  
  /// Register callback for when app resumes (comes to foreground)
  void addOnResumeCallback(VoidCallback callback) {
    _onResumeCallbacks.add(callback);
  }
  
  /// Register callback for when app pauses (goes to background)
  void addOnPauseCallback(VoidCallback callback) {
    _onPauseCallbacks.add(callback);
  }
  
  /// Register callback for when window gains focus
  void addOnWindowFocusCallback(VoidCallback callback) {
    _onWindowFocusCallbacks.add(callback);
  }
  
  /// Register callback for when window loses focus
  void addOnWindowBlurCallback(VoidCallback callback) {
    _onWindowBlurCallbacks.add(callback);
  }
  
  /// Remove resume callback
  void removeOnResumeCallback(VoidCallback callback) {
    _onResumeCallbacks.remove(callback);
  }
  
  /// Remove pause callback
  void removeOnPauseCallback(VoidCallback callback) {
    _onPauseCallbacks.remove(callback);
  }
  
  /// Remove window focus callback
  void removeOnWindowFocusCallback(VoidCallback callback) {
    _onWindowFocusCallbacks.remove(callback);
  }
  
  /// Remove window blur callback
  void removeOnWindowBlurCallback(VoidCallback callback) {
    _onWindowBlurCallbacks.remove(callback);
  }
  
  void _notifyResumeCallbacks() {
    for (final callback in _onResumeCallbacks) {
      try {
        callback();
      } catch (e) {
        // Ignore callback errors to prevent cascade failures
        debugPrint('Error in app resume callback: $e');
      }
    }
  }
  
  void _notifyPauseCallbacks() {
    for (final callback in _onPauseCallbacks) {
      try {
        callback();
      } catch (e) {
        // Ignore callback errors to prevent cascade failures
        debugPrint('Error in app pause callback: $e');
      }
    }
  }
  
  
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onResumeCallbacks.clear();
    _onPauseCallbacks.clear();
    _onWindowFocusCallbacks.clear();
    _onWindowBlurCallbacks.clear();
    super.dispose();
  }
}

/// Provider for app lifecycle state
final appLifecycleProvider = ChangeNotifierProvider<AppLifecycleManager>((ref) {
  return AppLifecycleManager.instance;
});

/// Provider for current app lifecycle state
final appLifecycleStateProvider = Provider<AppLifecycleState>((ref) {
  final manager = ref.watch(appLifecycleProvider);
  return manager.state;
});

/// Provider for whether app is in foreground
final isAppInForegroundProvider = Provider<bool>((ref) {
  final manager = ref.watch(appLifecycleProvider);
  return manager.isInForeground;
});
