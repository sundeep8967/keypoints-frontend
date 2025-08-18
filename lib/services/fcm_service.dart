import 'package:firebase_messaging/firebase_messaging.dart';
import 'reward_claims_service.dart';

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
      
      print('FCM Service initialized successfully');
    } catch (e) {
      print('FCM Service initialization error: $e');
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

      print('FCM Permission status: ${settings.authorizationStatus}');
    } catch (e) {
      print('Error requesting FCM permission: $e');
    }
  }

  /// Get FCM token and store in Supabase
  static Future<void> _getAndStoreToken() async {
    try {
      String? token = await _messaging!.getToken();
      
      if (token != null && token != _currentToken) {
        _currentToken = token;
        print('FCM Token obtained: $token');
        
        // Store FCM token in Supabase (without email for now)
        await _storeFCMTokenOnly(token);
      }
    } catch (e) {
      print('Error getting FCM token: $e');
    }
  }

  /// Store FCM token in Supabase without email
  static Future<void> _storeFCMTokenOnly(String fcmToken) async {
    try {
      // Check if this FCM token already exists
      final existingUser = await UserDataService.getUserByFCMToken(fcmToken);
      
      if (existingUser == null) {
        // Insert new record with temporary email
        await UserDataService.insertFCMTokenOnly(fcmToken);
        print('FCM token stored in Supabase successfully');
      } else {
        // Update existing record as active
        await UserDataService.markFCMTokenActive(fcmToken);
        print('FCM token marked as active in Supabase');
      }
    } catch (e) {
      print('Error storing FCM token in Supabase: $e');
    }
  }

  /// Setup listener for token refresh
  static void _setupTokenRefreshListener() {
    try {
      _messaging!.onTokenRefresh.listen((newToken) {
        print('FCM Token refreshed: $newToken');
        
        // Mark old token as inactive if different
        if (_currentToken != null && _currentToken != newToken) {
          UserDataService.markFCMTokenInactive(_currentToken!);
        }
        
        // Store new token
        _currentToken = newToken;
        _storeFCMTokenOnly(newToken);
      });
    } catch (e) {
      print('Error setting up FCM token refresh listener: $e');
    }
  }

  /// Get current FCM token
  static String? getCurrentToken() {
    return _currentToken;
  }

  /// Link email to existing FCM token (called when user claims reward)
  static Future<void> linkEmailToFCMToken(String email) async {
    if (_currentToken != null) {
      try {
        await UserDataService.linkEmailToFCMToken(_currentToken!, email);
        print('Email linked to FCM token successfully');
      } catch (e) {
        print('Error linking email to FCM token: $e');
      }
    }
  }

  /// Initialize FCM after core app functionality (background task)
  static Future<void> initializeWhenReady() async {
    // Add a small delay to ensure core functionality is loaded first
    await Future.delayed(const Duration(seconds: 2));
    
    print('Starting FCM initialization (background task)...');
    await initialize();
  }
}