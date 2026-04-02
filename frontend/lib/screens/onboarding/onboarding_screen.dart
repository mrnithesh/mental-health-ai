import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/constants.dart';
import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/nickname_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/voice_provider.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/user_avatar.dart';
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
    await ref.read(firestoreServiceProvider).setOnboardingComplete();
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
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const AppLogo(withText: true, size: 120, borderRadius: 28),
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

class _NicknamePage extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onNext;
  const _NicknamePage({required this.controller, required this.onNext});

  @override
  State<_NicknamePage> createState() => _NicknamePageState();
}

class _NicknamePageState extends State<_NicknamePage> {
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChange);
  }

  void _onTextChange() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final typedName = widget.controller.text.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar preview — live-updates as the user types
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              UserAvatar(
                user: _user,
                displayName: typedName.isNotEmpty ? typedName : null,
                size: 88,
                borderColor: AppColors.primary.withValues(alpha: 0.35),
                borderWidth: 3,
              ),
              // Small edit badge
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.edit_rounded,
                    color: Colors.white, size: 13),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
          const SizedBox(height: 28),
          TextField(
            controller: widget.controller,
            textCapitalization: TextCapitalization.words,
            textAlign: TextAlign.center,
            autofocus: true,
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
                borderSide: const BorderSide(color: AppColors.surfaceVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: const BorderSide(color: AppColors.surfaceVariant),
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
              onPressed: widget.onNext,
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

class _ReadyPage extends StatefulWidget {
  final String nickname;
  final String voiceName;
  final VoidCallback onFinish;

  const _ReadyPage({
    required this.nickname,
    required this.voiceName,
    required this.onFinish,
  });

  @override
  State<_ReadyPage> createState() => _ReadyPageState();
}

class _ReadyPageState extends State<_ReadyPage> {
  bool _agreedToTerms = false;

  void _showTerms() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        builder: (ctx, scrollController) => _TermsContent(
          scrollController: scrollController,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final displayName = widget.nickname.isNotEmpty ? widget.nickname : 'Friend';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          UserAvatar(
            user: FirebaseAuth.instance.currentUser,
            displayName: widget.nickname.isNotEmpty ? widget.nickname : null,
            size: 88,
            borderColor: AppColors.primary.withValues(alpha: 0.4),
            borderWidth: 3,
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
                _SummaryRow(label: 'Your name', value: displayName),
                const SizedBox(height: 12),
                _SummaryRow(label: 'Your Amigo', value: widget.voiceName),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxTheme(
                  data: CheckboxThemeData(
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return AppColors.primary;
                      }
                      return Colors.transparent;
                    }),
                    checkColor: WidgetStateProperty.all(Colors.white),
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      width: 2,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Checkbox(
                    value: _agreedToTerms,
                    onChanged: (v) =>
                        setState(() => _agreedToTerms = v ?? false),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: _showTerms,
                    child: Text.rich(
                      TextSpan(
                        text: 'I agree to the ',
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.35,
                          color: AppColors.textPrimary,
                        ),
                        children: [
                          TextSpan(
                            text: 'Terms & Conditions',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _agreedToTerms ? widget.onFinish : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.surfaceVariant,
                disabledForegroundColor: AppColors.textSecondary,
              ),
              child: const Text('Let\'s Go!'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsContent extends StatelessWidget {
  final ScrollController scrollController;
  final VoidCallback onClose;

  const _TermsContent({required this.scrollController, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text('Terms & Conditions',
              style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: const [
                _TermsSection(
                  title: 'Prototype Disclaimer',
                  body: 'Amigo is a prototype AI companion application developed for research and personal wellness exploration. It is NOT a finished commercial product and may contain bugs, errors, or unexpected behaviors.',
                ),
                _TermsSection(
                  title: 'Not a Medical Device',
                  body: 'Amigo is NOT a medical device, diagnostic tool, or therapeutic service. It is not a substitute for professional medical advice, diagnosis, or treatment. Never disregard professional medical or mental health advice because of something Amigo has said.',
                ),
                _TermsSection(
                  title: 'Not a Crisis Service',
                  body: 'Amigo is not equipped to handle mental health crises. If you are experiencing a medical or mental health emergency, please contact your local emergency services, a crisis helpline, or a qualified mental health professional immediately.',
                ),
                _TermsSection(
                  title: 'AI Limitations',
                  body: 'Amigo uses AI language models that may occasionally produce inaccurate, inappropriate, or unhelpful responses. The AI does not truly understand emotions or have feelings. Its responses are generated based on patterns, not genuine empathy.',
                ),
                _TermsSection(
                  title: 'Data & Privacy',
                  body: 'Your conversations, journal entries, and mood data are stored in your personal Firebase account. We do not sell or share your personal data with third parties. Conversations are processed by Google\'s Gemini AI models for response generation.',
                ),
                _TermsSection(
                  title: 'Use at Your Own Risk',
                  body: 'By using Amigo, you acknowledge that this is a prototype and accept all associated risks. The developers are not liable for any outcomes resulting from use of this application.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onClose,
              child: const Text('I Understand'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String body;
  const _TermsSection({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: AppColors.textPrimary)),
          const SizedBox(height: 6),
          Text(body, style: TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
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
