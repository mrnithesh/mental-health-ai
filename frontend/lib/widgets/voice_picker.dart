import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../config/theme.dart';

class VoicePicker extends StatelessWidget {
  final String selectedVoiceId;
  final ValueChanged<String> onVoiceSelected;

  const VoicePicker({
    super.key,
    required this.selectedVoiceId,
    required this.onVoiceSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: AmigoVoice.all.map((voice) {
        final isSelected = voice.id == selectedVoiceId;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _VoiceCard(
            voice: voice,
            isSelected: isSelected,
            onTap: voice.isAvailable
                ? () => onVoiceSelected(voice.id)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

class _VoiceCard extends StatelessWidget {
  final AmigoVoice voice;
  final bool isSelected;
  final VoidCallback? onTap;

  const _VoiceCard({
    required this.voice,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = !voice.isAvailable;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : isDisabled
                  ? AppColors.surfaceVariant
                  : const Color(0xFFE0DCD6),
          width: isSelected ? 1.5 : 1,
        ),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : isDisabled
                            ? AppColors.surfaceVariant.withValues(alpha: 0.6)
                            : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(
                    Icons.record_voice_over_rounded,
                    color: isSelected
                        ? AppColors.primary
                        : isDisabled
                            ? AppColors.textTertiary
                            : AppColors.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voice.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isDisabled
                              ? AppColors.textTertiary
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        voice.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDisabled
                              ? AppColors.textTertiary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isDisabled)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Coming Soon',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  )
                else if (isSelected)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  )
                else
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFE0DCD6),
                        width: 1.5,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
