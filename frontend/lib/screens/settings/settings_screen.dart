import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/routes.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nickname_provider.dart';
import '../../providers/service_providers.dart';
import '../../providers/voice_provider.dart';
import '../../widgets/voice_picker.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final user = FirebaseAuth.instance.currentUser;
    final selectedVoice = ref.watch(voicePreferenceProvider);
    final nickname = ref.watch(nicknameProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Settings',
                  style: tt.headlineLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              // ── Profile ──
              _ProfileCard(user: user, nickname: nickname),
              const SizedBox(height: 12),
              _NicknameEditor(
                nickname: nickname,
                onChanged: (v) =>
                    ref.read(nicknameProvider.notifier).setNickname(v),
              ),

              const SizedBox(height: 32),
              _SectionHeader(title: 'Choose Your Amigo',
                  subtitle: 'Pick the companion you want to chat and talk with'),
              const SizedBox(height: 14),
              VoicePicker(
                selectedVoiceId: selectedVoice,
                onVoiceSelected: (id) =>
                    ref.read(voicePreferenceProvider.notifier).setVoice(id),
              ),

              const SizedBox(height: 28),
              _SectionHeader(title: 'Personality',
                  subtitle: 'Customize how your Amigo behaves and responds'),
              const SizedBox(height: 14),
              _ComingSoonTile(
                icon: Icons.psychology_rounded,
                title: 'Custom Personality',
                subtitle: 'Adjust tone, style, and how your Amigo talks',
              ),

              const SizedBox(height: 32),
              _SectionHeader(title: 'Account'),
              const SizedBox(height: 14),
              _ActionTile(
                icon: Icons.logout_rounded,
                title: 'Sign Out',
                subtitle: 'You can always sign back in',
                color: AppColors.error,
                onTap: () => _confirmSignOut(context, ref),
              ),

              const SizedBox(height: 32),
              _SectionHeader(title: 'About'),
              const SizedBox(height: 14),
              _ActionTile(
                icon: Icons.info_outline_rounded,
                title: 'Amigo',
                subtitle: 'Version 1.0.0 — Your AI Companion',
                color: AppColors.primary,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    ref.read(geminiServiceProvider).resetForNewUser();
    ref.read(nicknameProvider.notifier).reset();
    await ref.read(authNotifierProvider.notifier).signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.login, (_) => false);
  }
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.w600,
            color: AppColors.textPrimary)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: TextStyle(
              fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
        ],
      ],
    );
  }
}

// ── Profile card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  final User? user;
  final String nickname;
  const _ProfileCard({this.user, required this.nickname});

  @override
  Widget build(BuildContext context) {
    final displayName =
        nickname.isNotEmpty ? nickname : (user?.displayName ?? 'Friend');
    final email = user?.email ?? '';
    final initials = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(email,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Nickname editor ──────────────────────────────────────────────────────────

class _NicknameEditor extends StatefulWidget {
  final String nickname;
  final ValueChanged<String> onChanged;
  const _NicknameEditor({required this.nickname, required this.onChanged});

  @override
  State<_NicknameEditor> createState() => _NicknameEditorState();
}

class _NicknameEditorState extends State<_NicknameEditor> {
  late TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.nickname);
  }

  @override
  void didUpdateWidget(_NicknameEditor old) {
    super.didUpdateWidget(old);
    if (!_editing && old.nickname != widget.nickname) {
      _controller.text = widget.nickname;
    }
  }

  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  void _save() {
    final value = _controller.text.trim();
    if (value.isNotEmpty) widget.onChanged(value);
    setState(() => _editing = false);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What should your Amigo call you?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  textCapitalization: TextCapitalization.words,
                  onTap: () => setState(() => _editing = true),
                  onSubmitted: (_) => _save(),
                  style: const TextStyle(fontSize: 15, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Your nickname',
                    hintStyle: const TextStyle(color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surfaceVariant.withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              if (_editing) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _save,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ── Action tile ──────────────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon, required this.title,
    required this.subtitle, required this.color, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: color == AppColors.error
                              ? AppColors.error : AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.textTertiary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Coming soon tile ─────────────────────────────────────────────────────────

class _ComingSoonTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ComingSoonTile({
    required this.icon, required this.title, required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.surfaceVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: AppColors.textTertiary, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500,
                    color: AppColors.textTertiary)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(
                    fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Coming Soon', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: AppColors.textTertiary)),
          ),
        ],
      ),
    );
  }
}
