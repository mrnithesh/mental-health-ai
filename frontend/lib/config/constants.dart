class AppConstants {
  // Pagination
  static const int defaultPageSize = 20;
  
  // Mood score range
  static const int moodScoreMin = 1;
  static const int moodScoreMax = 5;
  
  // Journal
  static const int journalTitleMaxLength = 100;
  static const int journalContentMaxLength = 10000;
  
  // Chat
  static const int maxMessageLength = 2000;
  static const int maxConversationHistory = 50;
  
  // Voice
  static const int voiceSessionMaxDuration = 600; // 10 minutes in seconds
  
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String themeKey = 'theme_mode';
  static const String onboardingKey = 'onboarding_complete';
}

class MoodEmojis {
  static const Map<int, String> scoreToEmoji = {
    1: '😢',
    2: '😕',
    3: '😐',
    4: '🙂',
    5: '😄',
  };
  
  static const Map<int, String> scoreToLabel = {
    1: 'Terrible',
    2: 'Bad',
    3: 'Okay',
    4: 'Good',
    5: 'Excellent',
  };
}
