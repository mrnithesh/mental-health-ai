import 'package:flutter/widgets.dart';

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

class JournalTemplate {
  final String id;
  final String name;
  final String description;
  final String icon;
  final List<String> prompts;

  const JournalTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.prompts,
  });

  static const List<JournalTemplate> all = [
    JournalTemplate(
      id: 'gratitude',
      name: 'Gratitude',
      description: 'Focus on what you appreciate',
      icon: '🙏',
      prompts: [
        'What are you grateful for today?',
        'Who made a positive impact on you recently?',
        'What small moment brought you joy?',
      ],
    ),
    JournalTemplate(
      id: 'daily_debrief',
      name: 'Daily Debrief',
      description: 'Reflect on your day',
      icon: '🌙',
      prompts: [
        'What was the best part of your day?',
        'What drained your energy?',
        'What would you do differently tomorrow?',
      ],
    ),
    JournalTemplate(
      id: 'anxiety_dump',
      name: 'Anxiety Dump',
      description: 'Work through your worries',
      icon: '🌊',
      prompts: [
        "What's worrying you right now?",
        "What's the worst that could happen?",
        "What's most likely to happen?",
        "What's within your control?",
      ],
    ),
    JournalTemplate(
      id: 'self_compassion',
      name: 'Self-Compassion',
      description: 'Be kind to yourself',
      icon: '💛',
      prompts: [
        "What's been hard for you lately?",
        'What would you say to a friend in this situation?',
        'What do you need right now?',
      ],
    ),
  ];

  static JournalTemplate? byId(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

class AmigoVoice {
  final String id;
  final String name;
  final String voiceCode;
  final String description;
  final String personality;
  final String sampleText;
  final IconData icon;
  final bool isAvailable;

  const AmigoVoice({
    required this.id,
    required this.name,
    required this.voiceCode,
    required this.description,
    required this.personality,
    this.sampleText = '',
    required this.icon,
    this.isAvailable = false,
  });

  static const String defaultVoiceId = 'leda';

  static const List<AmigoVoice> all = [
    AmigoVoice(
      id: 'leda',
      name: 'Nila',
      voiceCode: 'Leda',
      description: 'Warm & gentle (Female)',
      personality: 'You are Nila — a warm, empathetic female companion. You speak softly and gently, like a caring older sister. You are nurturing, patient, and always make the user feel safe and heard.',
      sampleText: "Hi! I'm நிலா, I'll be here whenever you need to talk.",
      icon: IconData(0xe491, fontFamily: 'MaterialIcons'),
      isAvailable: true,
    ),
    AmigoVoice(
      id: 'fenrir',
      name: 'Amigo',
      voiceCode: 'Fenrir',
      description: 'Calm & steady (Male)',
      personality: 'You are Amigo — a calm, grounded male companion. You have a steady, reassuring presence like a trusted best friend. You are laid-back, supportive, and encourage the user with quiet confidence.',
      sampleText: "Hey there! I'm Amigo. Let's chat about anything on your mind.",
      icon: IconData(0xe491, fontFamily: 'MaterialIcons'),
      isAvailable: true,
    ),
    AmigoVoice(
      id: 'nova',
      name: 'Nova',
      voiceCode: '',
      description: 'Cheerful & bright',
      personality: '',
      icon: IconData(0xe491, fontFamily: 'MaterialIcons'),
    ),
    AmigoVoice(
      id: 'sage',
      name: 'Sage',
      voiceCode: '',
      description: 'Thoughtful & calm',
      personality: '',
      icon: IconData(0xe491, fontFamily: 'MaterialIcons'),
    ),
  ];

  static AmigoVoice? byId(String id) {
    try {
      return all.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  static AmigoVoice get defaultVoice =>
      byId(defaultVoiceId) ?? all.first;
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
