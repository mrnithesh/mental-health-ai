import 'package:flutter/material.dart';

import '../screens/splash/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/phone_auth_screen.dart';
import '../screens/main_shell.dart';
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
  static const String main = '/main';
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

      case main:
        return MaterialPageRoute(builder: (_) => const MainShell());

      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());

      case chat:
        final conversationId = settings.arguments as String?;
        return _fadeSlideRoute(
          ChatScreen(conversationId: conversationId),
        );

      case voiceChat:
        return _fadeSlideRoute(const VoiceChatScreen());

      case journalList:
        return MaterialPageRoute(builder: (_) => const JournalListScreen());

      case journalEditor:
        final journalId = settings.arguments as String?;
        return _fadeSlideRoute(
          JournalEditorScreen(journalId: journalId),
        );

      case moodTracker:
        return MaterialPageRoute(builder: (_) => const MoodTrackerScreen());

      case moodHistory:
        return _fadeSlideRoute(const MoodHistoryScreen());

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

  static Route<T> _fadeSlideRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}
