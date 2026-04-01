import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/nickname_provider.dart';
import '../../providers/voice_provider.dart';
import '../../widgets/voice_picker.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  String _selectedVoice = AmigoVoice.defaultVoiceId;
  late TextEditingController _nicknameController;

  @override
  void initState() {
    super.initState();
    final fallback =
        FirebaseAuth.instance.currentUser?.displayName?.split(' ').first ?? '';
    _nicknameController = TextEditingController(text: fallback);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _back() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isNotEmpty) {
      await ref.read(nicknameProvider.notifier).setNickname(nickname);
    }
    await ref.read(voicePreferenceProvider.notifier).setVoice(_selectedVoice);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.main);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    GestureDetector(
                      onTap: _back,
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.textPrimary, size: 22),
                    )
                  else
                    const SizedBox(width: 22),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _WelcomePage(onNext: _next),
                  _NicknamePage(
                    controller: _nicknameController,
                    onNext: _next,
                  ),
                  _VoicePage(
                    selectedVoice: _selectedVoice,
                    onVoiceSelected: (id) =>
                        setState(() => _selectedVoice = id),
                    onNext: _next,
                  ),
                  _ReadyPage(
                    nickname: _nicknameController.text.trim(),
                    voiceName:
                        AmigoVoice.byId(_selectedVoice)?.name ?? 'Nila',
                    onFinish: _finish,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _currentPage
                          ? AppColors.primary
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final VoidCallback onNext;
  const _WelcomePage({required this.onNext});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 48),
          ),
          const SizedBox(height: 32),
          Text(
            'Welcome to Amigo',
            style: tt.headlineLarge?.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Your AI companion for\neveryday moments',
            style: tt.bodyLarge?.copyWith(
                color: AppColors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Get Started'),
            ),
          ),
        ],
      ),
    );
  }
}

class _NicknamePage extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onNext;
  const _NicknamePage({required this.controller, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child:
                const Icon(Icons.badge_rounded, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 28),
          Text(
            'What should your\nAmigo call you?',
            style: tt.headlineMedium?.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a name or nickname you like',
            style: tt.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Nithesh, Bro, Machan...',
              hintStyle: TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 16,
                  fontWeight: FontWeight.normal),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide(color: AppColors.surfaceVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide(color: AppColors.surfaceVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Continue'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoicePage extends StatelessWidget {
  final String selectedVoice;
  final ValueChanged<String> onVoiceSelected;
  final VoidCallback onNext;

  const _VoicePage({
    required this.selectedVoice,
    required this.onVoiceSelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.record_voice_over_rounded,
                color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 24),
          Text(
            'Choose Your Amigo',
            style: tt.headlineMedium?.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pick a companion that feels right for you',
            style: tt.bodyMedium?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: VoicePicker(
                selectedVoiceId: selectedVoice,
                onVoiceSelected: onVoiceSelected,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ReadyPage extends StatelessWidget {
  final String nickname;
  final String voiceName;
  final VoidCallback onFinish;

  const _ReadyPage({
    required this.nickname,
    required this.voiceName,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final displayName = nickname.isNotEmpty ? nickname : 'Friend';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.secondary, AppColors.primary],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 48),
          ),
          const SizedBox(height: 32),
          Text(
            'You\'re all set!',
            style: tt.headlineLarge?.copyWith(
                color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.surfaceVariant),
            ),
            child: Column(
              children: [
                _SummaryRow(
                    label: 'Your name', value: displayName),
                const SizedBox(height: 12),
                _SummaryRow(
                    label: 'Your Amigo', value: voiceName),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You can change these anytime in Settings',
            style: tt.bodySmall?.copyWith(color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onFinish,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Let\'s Go!'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ],
    );
  }
}
