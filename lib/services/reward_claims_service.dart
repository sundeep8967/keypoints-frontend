import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

import '../utils/app_logger.dart';
class UserDataService {
  static final _supabase = Supabase.instance.client;

  /// Create the user_data table in Supabase
  /// Run this SQL in your Supabase dashboard:
  /// 
  /// CREATE TABLE user_data (
  ///   fcm_token TEXT PRIMARY KEY,
  ///   email VARCHAR(255) NOT NULL,
  ///   points_claimed INTEGER DEFAULT 0,
  ///   total_remaining_points INTEGER DEFAULT 0,
  ///   active BOOLEAN DEFAULT true,
  ///   claim_status VARCHAR(50) DEFAULT 'none',
  ///   last_claim_date TIMESTAMP NULL,
  ///   created_at TIMESTAMP DEFAULT NOW(),
  ///   updated_at TIMESTAMP DEFAULT NOW()
  /// );

  /// Submit a reward claim or update user data
  static Future<bool> submitClaim({
    required String email,
    required String fullName,
    required int pointsClaimed,
    required int totalRemainingPoints,
    String? fcmToken,
  }) async {
    try {
      // Generate a temporary FCM token if none provided
      final tempFcmToken = fcmToken ?? 'temp_${email.hashCode}_${DateTime.now().millisecondsSinceEpoch}';
      
      // Check if user already exists by email
      final existingUser = await _supabase
          .from('user_data')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (existingUser != null) {
        // Update existing user with new claim
        await _supabase.from('user_data').update({
          'full_name': fullName,
          'points_claimed': pointsClaimed,
          'total_remaining_points': totalRemainingPoints,
          'claim_status': 'pending',
          'last_claim_date': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('fcm_token', existingUser['fcm_token']);
      } else {
        // Insert new user with temporary or real FCM token
        await _supabase.from('user_data').insert({
          'fcm_token': tempFcmToken,
          'email': email,
          'full_name': fullName,
          'points_claimed': pointsClaimed,
          'total_remaining_points': totalRemainingPoints,
          'active': true,
          'claim_status': 'pending',
          'last_claim_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      AppLogger.log('User data updated successfully for $email');
      return true;
    } catch (e) {
      AppLogger.log('Error updating user data: $e');
      return false;
    }
  }

  /// Update FCM token for notifications
  static Future<bool> updateFCMToken({
    required String email,
    required String fcmToken,
  }) async {
    try {
      final existingUser = await _supabase
          .from('user_data')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (existingUser != null) {
        // Delete old record and insert new one with new FCM token
        await _supabase.from('user_data').delete().eq('fcm_token', existingUser['fcm_token']);
        
        await _supabase.from('user_data').insert({
          'fcm_token': fcmToken,
          'email': email,
          'points_claimed': existingUser['points_claimed'] ?? 0,
          'total_remaining_points': existingUser['total_remaining_points'] ?? 0,
          'active': existingUser['active'] ?? true,
          'claim_status': existingUser['claim_status'] ?? 'none',
          'last_claim_date': existingUser['last_claim_date'],
          'created_at': existingUser['created_at'],
          'updated_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Insert new user with FCM token
        await _supabase.from('user_data').insert({
          'fcm_token': fcmToken,
          'email': email,
          'active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      AppLogger.log('FCM token updated successfully for $email');
      return true;
    } catch (e) {
      AppLogger.log('Error updating FCM token: $e');
      return false;
    }
  }

  /// Get all pending claims (for admin use)
  static Future<List<Map<String, dynamic>>> getPendingClaims() async {
    try {
      final response = await _supabase
          .from('user_data')
          .select()
          .eq('claim_status', 'pending')
          .eq('active', true)
          .order('last_claim_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.log('Error fetching pending claims: $e');
      return [];
    }
  }

  /// Mark claim as processed
  static Future<bool> markClaimProcessed(String email) async {
    try {
      await _supabase.from('user_data').update({
        'claim_status': 'processed',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('email', email);

      return true;
    } catch (e) {
      AppLogger.log('Error marking claim as processed: $e');
      return false;
    }
  }

  /// Get all users for notifications
  static Future<List<Map<String, dynamic>>> getAllActiveUsers() async {
    try {
      final response = await _supabase
          .from('user_data')
          .select()
          .eq('active', true)
          .not('fcm_token', 'is', null);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.log('Error fetching active users: $e');
      return [];
    }
  }

  /// Get user data by email
  static Future<Map<String, dynamic>?> getUserData(String email) async {
    try {
      final response = await _supabase
          .from('user_data')
          .select()
          .eq('email', email)
          .maybeSingle();

      return response;
    } catch (e) {
      AppLogger.log('Error fetching user data: $e');
      return null;
    }
  }

  /// Get user data by FCM token
  static Future<Map<String, dynamic>?> getUserByFCMToken(String fcmToken) async {
    try {
      final response = await _supabase
          .from('user_data')
          .select()
          .eq('fcm_token', fcmToken)
          .maybeSingle();

      return response;
    } catch (e) {
      AppLogger.log('Error fetching user by FCM token: $e');
      return null;
    }
  }

  /// Insert FCM token only (without email) for new app installs
  static Future<bool> insertFCMTokenOnly(String fcmToken) async {
    try {
      await _supabase.from('user_data').insert({
        'fcm_token': fcmToken,
        'active': true,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      AppLogger.log('FCM token inserted successfully');
      return true;
    } catch (e) {
      AppLogger.log('Error inserting FCM token: $e');
      return false;
    }
  }

  /// Link email to existing FCM token
  static Future<bool> linkEmailToFCMToken(String fcmToken, String email) async {
    try {
      await _supabase.from('user_data').update({
        'email': email,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('fcm_token', fcmToken);

      AppLogger.log('Email linked to FCM token successfully');
      return true;
    } catch (e) {
      AppLogger.log('Error linking email to FCM token: $e');
      return false;
    }
  }

  /// Mark FCM token as active
  static Future<bool> markFCMTokenActive(String fcmToken) async {
    try {
      await _supabase.from('user_data').update({
        'active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('fcm_token', fcmToken);

      return true;
    } catch (e) {
      AppLogger.log('Error marking FCM token as active: $e');
      return false;
    }
  }

  /// Mark FCM token as inactive
  static Future<bool> markFCMTokenInactive(String fcmToken) async {
    try {
      await _supabase.from('user_data').update({
        'active': false,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('fcm_token', fcmToken);

      return true;
    } catch (e) {
      AppLogger.log('Error marking FCM token as inactive: $e');
      return false;
    }
  }
}