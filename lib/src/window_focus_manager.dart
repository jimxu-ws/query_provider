import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages window focus detection for desktop and web platforms
class WindowFocusManager extends ChangeNotifier {
  static WindowFocusManager? _instance;
  
  /// Singleton instance
  static WindowFocusManager get instance {
    _instance ??= WindowFocusManager._();
    return _instance!;
  }
  
  WindowFocusManager._() {
    _initialize();
  }
  
  bool _windowHasFocus = true;
  final Set<VoidCallback> _onFocusCallbacks = {};
  final Set<VoidCallback> _onBlurCallbacks = {};
  
  /// Whether the window currently has focus
  bool get windowHasFocus => _windowHasFocus;
  
  /// Whether the window has lost focus
  bool get windowHasLostFocus => !_windowHasFocus;
  
  /// Whether window focus detection is supported on this platform
  bool get isSupported => kIsWeb || Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  
  void _initialize() {
    if (!isSupported) {
      return;
    }
    
    // Listen to window focus events
    _setupFocusListener();
  }
  
  void _setupFocusListener() {
    if (kIsWeb) {
      _setupWebFocusListener();
    } else {
      _setupDesktopFocusListener();
    }
  }
  
  /// Set up focus listener for web platform
  void _setupWebFocusListener() {
    // For web, we can use the HTML visibility API through platform channels
    // This is a simplified implementation - in a real app you might use js interop
    
    // Simulate focus detection for web (in a real implementation, you'd use js interop)
    Timer.periodic(const Duration(seconds: 1), (timer) {
      // This is a placeholder - real implementation would check document.hasFocus()
      // For demo purposes, we'll assume web always has focus
      if (!_windowHasFocus) {
        _handleFocusChange(true);
      }
    });
  }
  
  /// Set up focus listener for desktop platforms
  void _setupDesktopFocusListener() {
    // For desktop platforms, we can use platform-specific methods
    // This is a simplified implementation
    
    // Listen to app lifecycle changes which can indicate focus changes on desktop
    WidgetsBinding.instance.addObserver(_DesktopFocusObserver(this));
  }
  
  /// Handle focus change
  void _handleFocusChange(bool hasFocus) {
    final previousFocus = _windowHasFocus;
    _windowHasFocus = hasFocus;
    
    // Notify listeners
    notifyListeners();
    
    // Handle focus transitions
    if (!previousFocus && hasFocus) {
      // Window gained focus
      _notifyFocusCallbacks();
    } else if (previousFocus && !hasFocus) {
      // Window lost focus
      _notifyBlurCallbacks();
    }
  }
  
  /// Register callback for when window gains focus
  void addOnFocusCallback(VoidCallback callback) {
    _onFocusCallbacks.add(callback);
  }
  
  /// Register callback for when window loses focus
  void addOnBlurCallback(VoidCallback callback) {
    _onBlurCallbacks.add(callback);
  }
  
  /// Remove focus callback
  void removeOnFocusCallback(VoidCallback callback) {
    _onFocusCallbacks.remove(callback);
  }
  
  /// Remove blur callback
  void removeOnBlurCallback(VoidCallback callback) {
    _onBlurCallbacks.remove(callback);
  }
  
  void _notifyFocusCallbacks() {
    for (final callback in _onFocusCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Error in window focus callback: $e');
      }
    }
  }
  
  void _notifyBlurCallbacks() {
    for (final callback in _onBlurCallbacks) {
      try {
        callback();
      } catch (e) {
        debugPrint('Error in window blur callback: $e');
      }
    }
  }
  
  /// Manually trigger focus change (for testing or custom implementations)
  void setWindowFocus(bool hasFocus) {
    _handleFocusChange(hasFocus);
  }
  
  @override
  void dispose() {
    _onFocusCallbacks.clear();
    _onBlurCallbacks.clear();
    super.dispose();
  }
}

/// Observer for desktop focus detection
class _DesktopFocusObserver with WidgetsBindingObserver {
  
  _DesktopFocusObserver(this._manager);
  final WindowFocusManager _manager;
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // On desktop, app lifecycle changes can indicate window focus changes
    switch (state) {
      case AppLifecycleState.resumed:
        _manager._handleFocusChange(true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _manager._handleFocusChange(false);
        break;
      case AppLifecycleState.hidden:
        _manager._handleFocusChange(false);
        break;
    }
  }
}

/// Provider for window focus manager
final windowFocusManagerProvider = ChangeNotifierProvider<WindowFocusManager>((ref) {
  return WindowFocusManager.instance;
});

/// Provider for current window focus state
final windowFocusStateProvider = Provider<bool>((ref) {
  final manager = ref.watch(windowFocusManagerProvider);
  return manager.windowHasFocus;
});

/// Provider for whether window focus detection is supported
final windowFocusSupportedProvider = Provider<bool>((ref) {
  return WindowFocusManager.instance.isSupported;
});
