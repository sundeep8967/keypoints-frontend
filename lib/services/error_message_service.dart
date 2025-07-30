/// Service for converting technical errors into user-friendly messages
class ErrorMessageService {
  /// Converts technical error messages into user-friendly ones
  static String getUserFriendlyMessage(String error) {
    // Check for specific error patterns
    if (error.contains('NO_ARTICLES_IN_DATABASE') || 
        error.contains('No articles found in the database') ||
        error.contains('No articles found in Supabase')) {
      return 'You have read all articles!\nCheck back later for new content.';
    }
    
    if (error.contains('Failed to load news') || 
        error.contains('Failed to fetch news')) {
      return 'Unable to load articles.\nPlease check your internet connection and try again.';
    }
    
    if (error.contains('network') || 
        error.contains('connection') ||
        error.contains('timeout')) {
      return 'Network connection issue.\nPlease check your internet and try again.';
    }
    
    if (error.contains('Supabase') || 
        error.contains('database')) {
      return 'Service temporarily unavailable.\nPlease try again in a few moments.';
    }
    
    // Default user-friendly message for unknown errors
    return 'Something went wrong.\nPlease try again later.';
  }
  
  /// Checks if an error indicates all articles have been read
  static bool isAllArticlesReadError(String error) {
    return error.contains('NO_ARTICLES_IN_DATABASE') || 
           error.contains('No articles found in the database') ||
           error.contains('No articles found in Supabase');
  }
}