import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_logger.dart';

class StreaksService {
  static const String _currentStreakKey = 'current_streak';
  static const String _longestStreakKey = 'longest_streak';
  static const String _lastLoginDateKey = 'last_login_date';
  static const String _totalLoginsKey = 'total_logins';
  static const String _currentWeekKey = 'current_week';
  static const String _weeklyStreakKey = 'weekly_streak';
  static const String _longestWeeklyStreakKey = 'longest_weekly_streak';
  static const String _dailyUsageTimeKey = 'daily_usage_time';
  static const String _sessionStartTimeKey = 'session_start_time';

  static StreaksService? _instance;
  static StreaksService get instance => _instance ??= StreaksService._();

  StreaksService._();

  /// Start tracking usage session
  Future<void> startUsageSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionStartTime = DateTime.now().millisecondsSinceEpoch;
    await prefs.setInt(_sessionStartTimeKey, sessionStartTime);
    AppLogger.log('⏱️ Usage: Session started');
  }

  /// Stop tracking and update usage time
  Future<void> stopUsageSession() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionStartTime = prefs.getInt(_sessionStartTimeKey);
    
    if (sessionStartTime != null) {
      final sessionDuration = DateTime.now().millisecondsSinceEpoch - sessionStartTime;
      final sessionMinutes = (sessionDuration / 60000).round(); // Convert to minutes
      
      final today = _getTodayDate();
      final todayUsageKey = '${_dailyUsageTimeKey}_$today';
      final currentDailyUsage = prefs.getInt(todayUsageKey) ?? 0;
      final newDailyUsage = currentDailyUsage + sessionMinutes;
      
      await prefs.setInt(todayUsageKey, newDailyUsage);
      await prefs.remove(_sessionStartTimeKey);
      
      AppLogger.log('⏱️ Usage: Session ended, duration: ${sessionMinutes}min, daily total: ${newDailyUsage}min');
      
      // Check if user has met 7-minute requirement and update streak
      if (newDailyUsage >= 7) {
        await checkAndUpdateStreak();
      }
    }
  }

  /// Check current session time and update streak if 7-minute threshold is reached
  Future<void> checkLiveUsageAndUpdateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionStartTime = prefs.getInt(_sessionStartTimeKey);
    
    if (sessionStartTime != null) {
      final sessionDuration = DateTime.now().millisecondsSinceEpoch - sessionStartTime;
      final sessionMinutes = (sessionDuration / 60000).round();
      
      final today = _getTodayDate();
      final todayUsageKey = '${_dailyUsageTimeKey}_$today';
      final currentDailyUsage = prefs.getInt(todayUsageKey) ?? 0;
      final totalUsageToday = currentDailyUsage + sessionMinutes;
      
      AppLogger.log('⏱️ Live Usage Check: Current session: ${sessionMinutes}min, Total today: ${totalUsageToday}min');
      
      // If we've hit 7 minutes, update the streak immediately
      if (totalUsageToday >= 7) {
        // Temporarily save the current session time
        await prefs.setInt(todayUsageKey, totalUsageToday);
        await checkAndUpdateStreak();
        AppLogger.log('🔥 Live Streak Update: 7-minute threshold reached, streak updated!');
      }
    }
  }

  /// Get today's usage time in minutes
  Future<int> getTodayUsageTime() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _getTodayDate();
    final todayUsageKey = '${_dailyUsageTimeKey}_$today';
    return prefs.getInt(todayUsageKey) ?? 0;
  }

  /// Check if user has met today's 7-minute requirement
  Future<bool> hasMetTodayRequirement() async {
    final todayUsage = await getTodayUsageTime();
    return todayUsage >= 7;
  }

  /// Check and update streak (only after 7-minute requirement is met)
  Future<void> checkAndUpdateStreak() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _getTodayDate();
      final todayDateTime = DateTime.parse(today);
      final lastLoginDate = prefs.getString(_lastLoginDateKey);
      final currentStreak = prefs.getInt(_currentStreakKey) ?? 0;
      final longestStreak = prefs.getInt(_longestStreakKey) ?? 0;
      final totalLogins = prefs.getInt(_totalLoginsKey) ?? 0;
      
      // Weekly streak tracking
      final currentWeek = _getWeekIdentifier(todayDateTime);
      final lastWeek = prefs.getString(_currentWeekKey);
      final weeklyStreak = prefs.getInt(_weeklyStreakKey) ?? 0;
      final longestWeeklyStreak = prefs.getInt(_longestWeeklyStreakKey) ?? 0;

      AppLogger.log('🔥 Streaks: Checking streak for today: $today');
      AppLogger.log('🔥 Streaks: Last login date: $lastLoginDate');
      AppLogger.log('🔥 Streaks: Current daily streak: $currentStreak');
      AppLogger.log('📅 Weekly: Current week: $currentWeek, Last week: $lastWeek');
      AppLogger.log('📅 Weekly: Weekly streak: $weeklyStreak');

      // Check if user has met 7-minute requirement today
      final hasMetRequirement = await hasMetTodayRequirement();
      
      if (!hasMetRequirement) {
        AppLogger.log('🔥 Streaks: User has not met 7-minute requirement yet today');
        return; // Don't update streaks until requirement is met
      }

      if (lastLoginDate == null) {
        // First time user who met requirement
        await _setStreak(1, 1, today, 1);
        await _setWeeklyStreak(1, 1, currentWeek);
        AppLogger.log('🔥 Streaks: First time user, daily streak set to 1, weekly streak day 1 (7min requirement met)');
      } else if (lastLoginDate == today) {
        // Already logged in today and met requirement
        AppLogger.log('🔥 Streaks: Already logged in today and met 7-minute requirement');
        // But check if we need to update weekly tracking
        await _updateWeeklyProgress(todayDateTime, currentWeek, lastWeek, weeklyStreak, longestWeeklyStreak);
      } else {
        final lastLogin = DateTime.parse(lastLoginDate);
        final daysDifference = todayDateTime.difference(lastLogin).inDays;

        AppLogger.log('🔥 Streaks: Days difference: $daysDifference');

        // Update daily streak
        if (daysDifference == 1) {
          // Consecutive day login - increment streak
          final newStreak = currentStreak + 1;
          final newLongest = newStreak > longestStreak ? newStreak : longestStreak;
          await _setStreak(newStreak, newLongest, today, totalLogins + 1);
          AppLogger.log('🔥 Streaks: Consecutive day! New streak: $newStreak');
        } else {
          // Streak broken - reset to 1
          await _setStreak(1, longestStreak, today, totalLogins + 1);
          AppLogger.log('🔥 Streaks: Streak broken! Reset to 1');
        }
        
        // Update weekly streak
        await _updateWeeklyProgress(todayDateTime, currentWeek, lastWeek, weeklyStreak, longestWeeklyStreak);
      }
    } catch (e) {
      AppLogger.error('🔥 Streaks: Error checking streak: $e');
    }
  }

  /// Get current streak count
  Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_currentStreakKey) ?? 0;
  }

  /// Get longest streak count
  Future<int> getLongestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_longestStreakKey) ?? 0;
  }

  /// Get total login count
  Future<int> getTotalLogins() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_totalLoginsKey) ?? 0;
  }

  /// Get last login date
  Future<String?> getLastLoginDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastLoginDateKey);
  }

  /// Get current weekly streak (1-7, resets every Sunday)
  Future<int> getCurrentWeeklyStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_weeklyStreakKey) ?? 0;
  }

  /// Get longest weekly streak achieved
  Future<int> getLongestWeeklyStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_longestWeeklyStreakKey) ?? 0;
  }

  /// Get streak statistics including weekly
  Future<Map<String, dynamic>> getStreakStats() async {
    final currentStreak = await getCurrentStreak();
    final longestStreak = await getLongestStreak();
    final totalLogins = await getTotalLogins();
    final lastLoginDate = await getLastLoginDate();
    final weeklyStreak = await getCurrentWeeklyStreak();
    final longestWeeklyStreak = await getLongestWeeklyStreak();
    
    final today = DateTime.now();
    final dayOfWeek = _getDayOfWeek(today);
    final daysUntilSunday = _getDaysUntilSunday(today);
    final todayUsage = await getTodayUsageTime();
    final hasMetRequirement = await hasMetTodayRequirement();

    return {
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'totalLogins': totalLogins,
      'lastLoginDate': lastLoginDate,
      'weeklyStreak': weeklyStreak,
      'longestWeeklyStreak': longestWeeklyStreak,
      'currentDayOfWeek': dayOfWeek,
      'daysUntilWeekReset': daysUntilSunday,
      'todayUsageMinutes': todayUsage,
      'hasMetTodayRequirement': hasMetRequirement,
    };
  }

  /// Reset streaks (for testing or user request)
  Future<void> resetStreaks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentStreakKey);
    await prefs.remove(_longestStreakKey);
    await prefs.remove(_lastLoginDateKey);
    await prefs.remove(_totalLoginsKey);
    await prefs.remove(_currentWeekKey);
    await prefs.remove(_weeklyStreakKey);
    await prefs.remove(_longestWeeklyStreakKey);
    await prefs.remove(_sessionStartTimeKey);
    
    // Clear usage data for last 30 days
    final now = DateTime.now();
    for (int i = 0; i < 30; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      await prefs.remove('${_dailyUsageTimeKey}_$dateKey');
    }
    
    AppLogger.log('🔥 Streaks: All streaks and usage data reset');
  }

  /// Internal method to set streak data
  Future<void> _setStreak(int currentStreak, int longestStreak, String date, int totalLogins) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentStreakKey, currentStreak);
    await prefs.setInt(_longestStreakKey, longestStreak);
    await prefs.setString(_lastLoginDateKey, date);
    await prefs.setInt(_totalLoginsKey, totalLogins);
  }

  /// Get today's date in YYYY-MM-DD format
  String _getTodayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Check if streak is active (logged in today)
  Future<bool> isStreakActive() async {
    final lastLoginDate = await getLastLoginDate();
    if (lastLoginDate == null) return false;
    return lastLoginDate == _getTodayDate();
  }

  /// Get days until streak expires (always returns 1 if not logged in today)
  Future<int> getDaysUntilExpiry() async {
    final isActive = await isStreakActive();
    return isActive ? 1 : 0;
  }

  /// Update weekly progress
  Future<void> _updateWeeklyProgress(DateTime today, String currentWeek, String? lastWeek, int weeklyStreak, int longestWeeklyStreak) async {
    final dayOfWeek = _getDayOfWeek(today);
    
    if (lastWeek == null || lastWeek != currentWeek) {
      // New week started - reset weekly streak
      await _setWeeklyStreak(dayOfWeek, longestWeeklyStreak, currentWeek);
      AppLogger.log('📅 Weekly: New week started! Weekly streak set to day $dayOfWeek');
    } else {
      // Same week - update to current day of week
      final newWeeklyStreak = dayOfWeek;
      final newLongestWeekly = newWeeklyStreak > longestWeeklyStreak ? newWeeklyStreak : longestWeeklyStreak;
      await _setWeeklyStreak(newWeeklyStreak, newLongestWeekly, currentWeek);
      AppLogger.log('📅 Weekly: Updated to day $dayOfWeek of current week');
    }
  }

  /// Set weekly streak data
  Future<void> _setWeeklyStreak(int weeklyStreak, int longestWeeklyStreak, String currentWeek) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_weeklyStreakKey, weeklyStreak);
    await prefs.setInt(_longestWeeklyStreakKey, longestWeeklyStreak);
    await prefs.setString(_currentWeekKey, currentWeek);
  }

  /// Get week identifier (year-week format)
  String _getWeekIdentifier(DateTime date) {
    // Get the Monday of this week
    final monday = date.subtract(Duration(days: date.weekday - 1));
    return '${monday.year}-W${_getWeekOfYear(monday).toString().padLeft(2, '0')}';
  }

  /// Get week of year
  int _getWeekOfYear(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return ((daysSinceFirstDay + firstDayOfYear.weekday - 1) / 7).ceil();
  }

  /// Get day of week (1=Monday, 2=Tuesday, ..., 7=Sunday)
  int _getDayOfWeek(DateTime date) {
    return date.weekday == 7 ? 7 : date.weekday; // Sunday is 7, not 0
  }

  /// Get days until Sunday (week reset)
  int _getDaysUntilSunday(DateTime date) {
    final daysUntilSunday = 7 - date.weekday;
    return daysUntilSunday == 7 ? 0 : daysUntilSunday; // If today is Sunday, return 0
  }

  /// Get week progress as string (e.g., "Day 3 of 7")
  Future<String> getWeekProgressString() async {
    final weeklyStreak = await getCurrentWeeklyStreak();
    return 'Day $weeklyStreak of 7';
  }

  /// Check if weekly streak is complete (reached Sunday)
  Future<bool> isWeeklyStreakComplete() async {
    final weeklyStreak = await getCurrentWeeklyStreak();
    return weeklyStreak == 7;
  }
}
