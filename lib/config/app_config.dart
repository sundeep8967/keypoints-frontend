/// App configuration with secure credential management
class AppConfig {
  // Environment-based configuration
  static const String _supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '', // Empty default - must be provided via environment
  );
  
  static const String _supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY', 
    defaultValue: '', // Empty default - must be provided via environment
  );

  /// Get Supabase URL from environment variables
  static String get supabaseUrl {
    if (_supabaseUrl.isEmpty) {
      throw Exception(
        'SUPABASE_URL environment variable not set. '
        'Please configure your Supabase credentials properly.'
      );
    }
    return _supabaseUrl;
  }

  /// Get Supabase anonymous key from environment variables  
  static String get supabaseAnonKey {
    if (_supabaseAnonKey.isEmpty) {
      throw Exception(
        'SUPABASE_ANON_KEY environment variable not set. '
        'Please configure your Supabase credentials properly.'
      );
    }
    return _supabaseAnonKey;
  }

  /// Check if all required credentials are configured
  static bool get isConfigured {
    return _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;
  }

  /// Development/fallback configuration (for local development only)
  /// WARNING: Never commit real credentials to version control
  static const String _devSupabaseUrl = 'https://sopxrwmeojcsclhokeuy.supabase.co';
  static const String _devSupabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNvcHhyd21lb2pjc2NsaG9rZXV5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk4NDAwMDMsImV4cCI6MjA2NTQxNjAwM30.3shfwkFgJPOQ_wuYvdVmIzZrNONtQiwQFoAe5tthgSQ';

  /// Get development credentials (only for local development)
  /// This should be removed in production builds
  static String get devSupabaseUrl => _devSupabaseUrl;
  static String get devSupabaseAnonKey => _devSupabaseKey;

  /// Check if we're using development credentials
  static bool get isUsingDevCredentials {
    return !isConfigured && 
           _devSupabaseUrl != 'https://your-project.supabase.co' &&
           _devSupabaseKey != 'your-anon-key-here';
  }
}