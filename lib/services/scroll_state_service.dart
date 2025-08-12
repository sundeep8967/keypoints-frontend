import 'dart:async';

class ScrollStateService {
  static bool _isActivelyScrolling = false;
  static Timer? _scrollEndTimer;
  static final Duration _scrollEndDelay = const Duration(milliseconds: 1000);
  
  /// Track when user starts scrolling
  static void startScrolling() {
    _isActivelyScrolling = true;
    _cancelScrollEndTimer();
    print('📱 SCROLL STATE: User started scrolling - preventing cache modifications');
  }
  
  /// Track when user stops scrolling (with debounce)
  static void stopScrolling() {
    _cancelScrollEndTimer();
    _scrollEndTimer = Timer(_scrollEndDelay, () {
      _isActivelyScrolling = false;
      print('📱 SCROLL STATE: User stopped scrolling - cache modifications allowed');
    });
  }
  
  /// Check if user is currently scrolling
  static bool get isActivelyScrolling => _isActivelyScrolling;
  
  /// Force stop scrolling state (for category switches, etc.)
  static void forceStopScrolling() {
    _cancelScrollEndTimer();
    _isActivelyScrolling = false;
    print('📱 SCROLL STATE: Force stopped scrolling state');
  }
  
  static void _cancelScrollEndTimer() {
    _scrollEndTimer?.cancel();
    _scrollEndTimer = null;
  }
  
  /// Clean up resources
  static void dispose() {
    _cancelScrollEndTimer();
    _isActivelyScrolling = false;
  }
}