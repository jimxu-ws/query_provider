import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:query_provider/query_provider.dart';

void main() {
  group('WindowFocusManager', () {
    late WindowFocusManager manager;

    setUp(() {
      manager = WindowFocusManager.instance;
    });

    test('should be a singleton', () {
      final manager1 = WindowFocusManager.instance;
      final manager2 = WindowFocusManager.instance;
      
      expect(identical(manager1, manager2), true);
    });

    test('should have default window focus as true', () {
      expect(manager.windowHasFocus, true);
      expect(manager.windowHasLostFocus, false);
    });

    test('should detect platform support correctly', () {
      // This test depends on the platform it's running on
      // In a real test environment, you might want to mock this
      final expectedSupport = kIsWeb || 
          Platform.isWindows || 
          Platform.isMacOS || 
          Platform.isLinux;
      
      expect(manager.isSupported, expectedSupport);
    });

    test('should handle manual focus changes', () {
      var focusCallbackCalled = false;
      var blurCallbackCalled = false;
      
      manager.addOnFocusCallback(() {
        focusCallbackCalled = true;
      });
      
      manager.addOnBlurCallback(() {
        blurCallbackCalled = true;
      });
      
      // Simulate losing focus
      manager.setWindowFocus(false);
      expect(manager.windowHasFocus, false);
      expect(manager.windowHasLostFocus, true);
      expect(blurCallbackCalled, true);
      expect(focusCallbackCalled, false);
      
      // Reset flags
      focusCallbackCalled = false;
      blurCallbackCalled = false;
      
      // Simulate gaining focus
      manager.setWindowFocus(true);
      expect(manager.windowHasFocus, true);
      expect(manager.windowHasLostFocus, false);
      expect(focusCallbackCalled, true);
      expect(blurCallbackCalled, false);
    });

    test('should not trigger callbacks for same focus state', () {
      var focusCallbackCount = 0;
      
      manager.addOnFocusCallback(() {
        focusCallbackCount++;
      });
      
      // Already has focus by default
      manager.setWindowFocus(true);
      expect(focusCallbackCount, 0);
      
      // Lose and regain focus
      manager.setWindowFocus(false);
      manager.setWindowFocus(true);
      expect(focusCallbackCount, 1);
    });

    test('should handle multiple callbacks', () {
      var callback1Called = false;
      var callback2Called = false;
      
      manager.addOnFocusCallback(() {
        callback1Called = true;
      });
      
      manager.addOnFocusCallback(() {
        callback2Called = true;
      });
      
      manager.setWindowFocus(false);
      manager.setWindowFocus(true);
      
      expect(callback1Called, true);
      expect(callback2Called, true);
    });

    test('should remove callbacks correctly', () {
      var callbackCalled = false;
      
      void callback() {
        callbackCalled = true;
      }
      
      manager.addOnFocusCallback(callback);
      manager.removeOnFocusCallback(callback);
      
      manager.setWindowFocus(false);
      manager.setWindowFocus(true);
      
      expect(callbackCalled, false);
    });

    test('should handle blur callbacks correctly', () {
      var blurCallbackCalled = false;
      
      void blurCallback() {
        blurCallbackCalled = true;
      }
      
      manager.addOnBlurCallback(blurCallback);
      
      manager.setWindowFocus(false);
      expect(blurCallbackCalled, true);
      
      // Remove and test
      blurCallbackCalled = false;
      manager.removeOnBlurCallback(blurCallback);
      
      manager.setWindowFocus(true);
      manager.setWindowFocus(false);
      expect(blurCallbackCalled, false);
    });

    test('should handle callback errors gracefully', () {
      var goodCallbackCalled = false;
      
      manager.addOnFocusCallback(() {
        throw Exception('Test error');
      });
      
      manager.addOnFocusCallback(() {
        goodCallbackCalled = true;
      });
      
      // Should not throw and should call other callbacks
      expect(() {
        manager.setWindowFocus(false);
        manager.setWindowFocus(true);
      }, returnsNormally);
      
      expect(goodCallbackCalled, true);
    });

    test('should notify listeners on focus change', () {
      var notificationCount = 0;
      
      manager.addListener(() {
        notificationCount++;
      });
      
      manager.setWindowFocus(false);
      expect(notificationCount, 1);
      
      manager.setWindowFocus(true);
      expect(notificationCount, 2);
      
      // Same state shouldn't notify
      manager.setWindowFocus(true);
      expect(notificationCount, 2);
    });

    test('should clean up callbacks on dispose', () {
      var callbackCalled = false;
      
      manager.addOnFocusCallback(() {
        callbackCalled = true;
      });
      
      manager.dispose();
      
      // After dispose, callbacks should be cleared
      manager.setWindowFocus(false);
      manager.setWindowFocus(true);
      
      expect(callbackCalled, false);
    });

    test('should handle focus transitions correctly', () {
      final focusStates = <bool>[];
      
      manager.addOnFocusCallback(() {
        focusStates.add(true);
      });
      
      manager.addOnBlurCallback(() {
        focusStates.add(false);
      });
      
      // Sequence of focus changes
      manager.setWindowFocus(false); // blur
      manager.setWindowFocus(true);  // focus
      manager.setWindowFocus(false); // blur
      manager.setWindowFocus(true);  // focus
      
      expect(focusStates, [false, true, false, true]);
    });

    test('should maintain focus state correctly', () {
      expect(manager.windowHasFocus, true);
      
      manager.setWindowFocus(false);
      expect(manager.windowHasFocus, false);
      expect(manager.windowHasLostFocus, true);
      
      manager.setWindowFocus(true);
      expect(manager.windowHasFocus, true);
      expect(manager.windowHasLostFocus, false);
    });
  });

  group('_DesktopFocusObserver', () {
    // Note: _DesktopFocusObserver is a private class, so we test it indirectly
    // through the WindowFocusManager's behavior on desktop platforms
    
    test('should be created and used by WindowFocusManager on supported platforms', () {
      final manager = WindowFocusManager.instance;
      
      // The manager should initialize without errors
      expect(manager, isNotNull);
      expect(manager.windowHasFocus, true);
    });
  });
}
