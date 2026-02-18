import 'package:flutter/material.dart';

import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/phone_auth_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/voice/voice_chat_screen.dart';
import '../screens/journal/journal_list_screen.dart';
import '../screens/journal/journal_editor_screen.dart';
import '../screens/mood/mood_tracker_screen.dart';
import '../screens/mood/mood_history_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String phoneAuth = '/phone-auth';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String voiceChat = '/voice-chat';
  static const String journalList = '/journal';
  static const String journalEditor = '/journal/editor';
  static const String moodTracker = '/mood';
  static const String moodHistory = '/mood/history';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      
      case phoneAuth:
        return MaterialPageRoute(builder: (_) => const PhoneAuthScreen());
      
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      
      case chat:
        final conversationId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(conversationId: conversationId),
        );
      
      case voiceChat:
        return MaterialPageRoute(builder: (_) => const VoiceChatScreen());
      
      case journalList:
        return MaterialPageRoute(builder: (_) => const JournalListScreen());
      
      case journalEditor:
        final journalId = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => JournalEditorScreen(journalId: journalId),
        );
      
      case moodTracker:
        return MaterialPageRoute(builder: (_) => const MoodTrackerScreen());
      
      case moodHistory:
        return MaterialPageRoute(builder: (_) => const MoodHistoryScreen());
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
