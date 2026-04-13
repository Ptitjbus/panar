class AppConstants {
  // App Info
  static const String appName = 'Panar';

  // SharedPreferences Keys
  static const String hasCompletedOnboardingKey = 'has_completed_onboarding';

  // Onboarding Content
  static const List<Map<String, String>> onboardingContent = [
    {
      'title': 'Welcome to Panar',
      'description':
          'Your personal assistant for managing tasks and staying organized.',
    },
    {
      'title': 'Stay Connected',
      'description':
          'Sync across all your devices and never miss an important update.',
    },
  ];

  // Validation
  static const int minUsernameLength = 3;
  static const int maxUsernameLength = 30;
  static const int minPasswordLength = 8;

  // OAuth Redirect
  static const String oauthRedirectScheme = 'com.example.panar';
  static const String oauthRedirectHost = 'login-callback';
}
