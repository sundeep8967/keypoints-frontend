import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class RewardPointsService {
  static const String _pointsKey = 'user_points';
  static const String _transactionsKey = 'points_transactions';
  static const String _dailyEarningsKey = 'daily_earnings';
  
  // Revenue sharing configuration
  static const double USER_REVENUE_SHARE = 0.30; // 30% to user, 70% to you
  static const int POINTS_PER_DOLLAR = 1000; // 1000 points = $1
  
  // Estimated native ad revenue (industry averages)
  static const double NATIVE_AD_REVENUE = 0.005; // $0.005 per impression
  static const double NATIVE_AD_CLICK_REVENUE = 0.02; // $0.02 per click
  
  static RewardPointsService? _instance;
  static RewardPointsService get instance => _instance ??= RewardPointsService._();
  
  RewardPointsService._();
  
  /// Get current points balance
  Future<int> getPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pointsKey) ?? 0;
  }
  
  /// Add points for ad impression
  Future<void> addPointsForAdImpression(String adId) async {
    final userRevenue = NATIVE_AD_REVENUE * USER_REVENUE_SHARE;
    final points = (userRevenue * POINTS_PER_DOLLAR).round();
    
    await _addPoints(points, 'native_ad_impression', adId);
    print('💰 Earned $points points for ad impression: $adId');
  }
  
  /// Add points for ad click
  Future<void> addPointsForAdClick(String adId) async {
    final userRevenue = NATIVE_AD_CLICK_REVENUE * USER_REVENUE_SHARE;
    final points = (userRevenue * POINTS_PER_DOLLAR).round();
    
    await _addPoints(points, 'native_ad_click', adId);
    print('💰 Earned $points points for ad click: $adId');
  }
  
  /// Internal method to add points
  Future<void> _addPoints(int points, String type, String adId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Update total points
    final currentPoints = await getPoints();
    final newTotal = currentPoints + points;
    await prefs.setInt(_pointsKey, newTotal);
    
    // Add transaction record
    await _addTransaction(points, type, adId);
    
    // Update daily earnings
    await _updateDailyEarnings(points);
  }
  
  /// Add transaction record
  Future<void> _addTransaction(int points, String type, String adId) async {
    final prefs = await SharedPreferences.getInstance();
    final transactionsJson = prefs.getString(_transactionsKey) ?? '[]';
    final transactions = List<Map<String, dynamic>>.from(
      json.decode(transactionsJson)
    );
    
    final transaction = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'points': points,
      'type': type,
      'adId': adId,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    transactions.add(transaction);
    
    // Keep only last 100 transactions to prevent storage bloat
    if (transactions.length > 100) {
      transactions.removeRange(0, transactions.length - 100);
    }
    
    await prefs.setString(_transactionsKey, json.encode(transactions));
  }
  
  /// Update daily earnings
  Future<void> _updateDailyEarnings(int points) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().split('T')[0];
    final dailyEarningsJson = prefs.getString(_dailyEarningsKey) ?? '{}';
    final dailyEarnings = Map<String, dynamic>.from(
      json.decode(dailyEarningsJson)
    );
    
    dailyEarnings[today] = (dailyEarnings[today] ?? 0) + points;
    
    // Keep only last 30 days
    final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
    dailyEarnings.removeWhere((date, _) {
      final dateTime = DateTime.parse(date);
      return dateTime.isBefore(cutoffDate);
    });
    
    await prefs.setString(_dailyEarningsKey, json.encode(dailyEarnings));
  }
  
  /// Get transaction history
  Future<List<Map<String, dynamic>>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final transactionsJson = prefs.getString(_transactionsKey) ?? '[]';
    return List<Map<String, dynamic>>.from(json.decode(transactionsJson));
  }
  
  /// Get daily earnings for last 7 days
  Future<Map<String, int>> getWeeklyEarnings() async {
    final prefs = await SharedPreferences.getInstance();
    final dailyEarningsJson = prefs.getString(_dailyEarningsKey) ?? '{}';
    final dailyEarnings = Map<String, dynamic>.from(
      json.decode(dailyEarningsJson)
    );
    
    final weeklyEarnings = <String, int>{};
    for (int i = 6; i >= 0; i--) {
      final date = DateTime.now().subtract(Duration(days: i));
      final dateStr = date.toIso8601String().split('T')[0];
      weeklyEarnings[dateStr] = dailyEarnings[dateStr] ?? 0;
    }
    
    return weeklyEarnings;
  }
  
  /// Get today's earnings
  Future<int> getTodayEarnings() async {
    final weeklyEarnings = await getWeeklyEarnings();
    final today = DateTime.now().toIso8601String().split('T')[0];
    return weeklyEarnings[today] ?? 0;
  }
  
  /// Get statistics
  Future<Map<String, dynamic>> getStats() async {
    final transactions = await getTransactions();
    final totalPoints = await getPoints();
    final todayEarnings = await getTodayEarnings();
    
    final impressionCount = transactions.where((t) => t['type'] == 'native_ad_impression').length;
    final clickCount = transactions.where((t) => t['type'] == 'native_ad_click').length;
    
    return {
      'totalPoints': totalPoints,
      'todayEarnings': todayEarnings,
      'totalImpressions': impressionCount,
      'totalClicks': clickCount,
      'estimatedEarnings': (totalPoints / POINTS_PER_DOLLAR).toStringAsFixed(4),
      'clickThroughRate': impressionCount > 0 ? (clickCount / impressionCount * 100).toStringAsFixed(2) : '0.00',
    };
  }
  
  /// Convert points to currency display
  String pointsToCurrency(int points) {
    final dollars = points / POINTS_PER_DOLLAR;
    return '\$${dollars.toStringAsFixed(4)}';
  }
  
  /// Get points needed for next milestone
  int getPointsToNextMilestone(int currentPoints) {
    final milestones = [100, 500, 1000, 2500, 5000, 10000];
    for (final milestone in milestones) {
      if (currentPoints < milestone) {
        return milestone - currentPoints;
      }
    }
    return 0; // Already at highest milestone
  }
}