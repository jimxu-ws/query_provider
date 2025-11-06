import 'dart:io';
import 'dart:js_interop' if (dart.library.html) 'dart:js_interop' ;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' if (dart.library.html) 'package:web/web.dart';

/// Manages window focus detection for desktop and web platforms
class WindowFocusManager extends ChangeNotifier {
  
  /// Singleton instance
  factory WindowFocusManager() {
    _instance ??= WindowFocusManager._();
    return _instance!;
  }
  
  WindowFocusManager._() {
    _initialize();
  }
  static WindowFocusManager? _instance;
  
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
    _WebFocusObserver(this);
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
  // ignore: avoid_positional_boolean_parameters
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

class _WebFocusObserver {
  factory _WebFocusObserver(WindowFocusManager manager) {
    _instance ??= _WebFocusObserver._(manager);
    return _instance!;
  }
  
  _WebFocusObserver._(this._manager) {
    _setupFocusListener();
  }
  EventListener? _focusListener;
  EventListener? _blurListener;
  final WindowFocusManager _manager;
  static _WebFocusObserver? _instance;

  void _setupFocusListener() {
    // Bind listeners using JS interop.
    _focusListener = ((Event event) => _manager._handleFocusChange(true)).toJS;
    _blurListener = ((Event event) => _manager._handleFocusChange(false)).toJS;
    window.addEventListener('focus', _focusListener);
    window.addEventListener('blur', _blurListener);
  }

  // void _clear() {
  //   // Remove listeners.
  //   if (_focusListener != null) {
  //     window.removeEventListener('focus', _focusListener!);
  //     _focusListener = null;
  //   }
  //   if (_blurListener != null) {
  //     window.removeEventListener('blur', _blurListener!);
  //     _blurListener = null;
  //   }
  // }
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
  return WindowFocusManager();
});

/// Provider for current window focus state
final windowFocusStateProvider = Provider<bool>((ref) {
  final manager = ref.watch(windowFocusManagerProvider);
  return manager.windowHasFocus;
});

/// Provider for whether window focus detection is supported
final windowFocusSupportedProvider = Provider<bool>((ref) {
  return WindowFocusManager().isSupported;
});
