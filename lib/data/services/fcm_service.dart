import 'package:firebase_messaging/firebase_messaging.dart';

import '../../core/utils/app_logger.dart';
class FCMService {
  static FirebaseMessaging? _messaging;
  static String? _currentToken;

  /// Initialize FCM service (call this after core app functionality is ready)
  static Future<void> initialize() async {
    try {
      _messaging = FirebaseMessaging.instance;
      
      // Request permission for notifications
      await _requestPermission();
      
      // Get initial FCM token
      await _getAndStoreToken();
      
      // Listen for token refresh
      _setupTokenRefreshListener();
      
      AppLogger.log('FCM Service initialized successfully');
    } catch (e) {
      AppLogger.log('FCM Service initialization error: $e');
    }
  }

  /// Request notification permissions
  static Future<void> _requestPermission() async {
    try {
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      AppLogger.log('FCM Permission status: ${settings.authorizationStatus}');
    } catch (e) {
      AppLogger.log('Error requesting FCM permission: $e');
    }
  }

  /// Get FCM token
  static Future<void> _getAndStoreToken() async {
    try {
      String? token = await _messaging!.getToken();
      
      if (token != null && token != _currentToken) {
        _currentToken = token;
        AppLogger.log('FCM Token obtained: $token');
      }
    } catch (e) {
      AppLogger.log('Error getting FCM token: $e');
    }
  }

  /// Setup listener for token refresh
  static void _setupTokenRefreshListener() {
    try {
      _messaging!.onTokenRefresh.listen((newToken) {
        AppLogger.log('FCM Token refreshed: $newToken');
        
        // Store new token
        _currentToken = newToken;
      });
    } catch (e) {
      AppLogger.log('Error setting up FCM token refresh listener: $e');
    }
  }

  /// Get current FCM token
  static String? getCurrentToken() {
    return _currentToken;
  }

  /// Initialize FCM after core app functionality (background task)
  static Future<void> initializeWhenReady() async {
    // Add a small delay to ensure core functionality is loaded first
    await Future.delayed(const Duration(seconds: 2));
    
    AppLogger.log('Starting FCM initialization (background task)...');
    await initialize();
  }
}