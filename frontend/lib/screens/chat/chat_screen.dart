import 'package:flutter/material.dart';

import '../../config/theme.dart';

class ChatScreen extends StatelessWidget {
  final String? conversationId;

  const ChatScreen({super.key, this.conversationId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: AppColors.secondary,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'AI Chat',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Coming Soon',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Text conversations with your AI companion will be available in the next update.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textTertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
