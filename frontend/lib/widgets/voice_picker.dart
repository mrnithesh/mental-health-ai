import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/constants.dart';
import '../config/theme.dart';
import '../providers/service_providers.dart';
import '../utils/audio_output.dart';

class VoicePicker extends ConsumerStatefulWidget {
  final String selectedVoiceId;
  final ValueChanged<String> onVoiceSelected;

  const VoicePicker({
    super.key,
    required this.selectedVoiceId,
    required this.onVoiceSelected,
  });

  @override
  ConsumerState<VoicePicker> createState() => _VoicePickerState();
}

class _VoicePickerState extends ConsumerState<VoicePicker> {
  final AudioOutput _audioOutput = AudioOutput();
  String? _loadingVoiceId;
  String? _playingVoiceId;
  bool _audioInitialized = false;

  @override
  void dispose() {
    _stopPreview();
    _audioOutput.dispose();
    super.dispose();
  }

  Future<void> _playPreview(AmigoVoice voice) async {
    if (_loadingVoiceId != null) return;
    if (!voice.isAvailable || voice.voiceCode.isEmpty || voice.sampleText.isEmpty) return;

    if (_playingVoiceId == voice.id) {
      await _stopPreview();
      return;
    }

    await _stopPreview();
    setState(() => _loadingVoiceId = voice.id);

    try {
      if (!_audioInitialized) {
        await _audioOutput.init();
        _audioInitialized = true;
      }
      await _audioOutput.playStream();

      final geminiService = ref.read(geminiServiceProvider);
      bool gotFirstAudio = false;
      await geminiService.previewVoice(
        voiceCode: voice.voiceCode,
        sampleText: voice.sampleText,
        audioOutput: _audioOutput,
        onFirstAudio: () {
          if (mounted && !gotFirstAudio) {
            gotFirstAudio = true;
            setState(() {
              _loadingVoiceId = null;
              _playingVoiceId = voice.id;
            });
          }
        },
      );

      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('Voice preview failed: $e');
    }

    if (mounted) {
      try { await _audioOutput.stopStream(); } catch (_) {}
      setState(() {
        _loadingVoiceId = null;
        _playingVoiceId = null;
      });
    }
  }

  Future<void> _stopPreview() async {
    try { await _audioOutput.stopStream(); } catch (_) {}
    if (mounted) {
      setState(() {
        _loadingVoiceId = null;
        _playingVoiceId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: AmigoVoice.all.map((voice) {
        final isSelected = voice.id == widget.selectedVoiceId;
        final isLoading = _loadingVoiceId == voice.id;
        final isPlaying = _playingVoiceId == voice.id;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _VoiceCard(
            voice: voice,
            isSelected: isSelected,
            isLoading: isLoading,
            isPlaying: isPlaying,
            onTap: voice.isAvailable
                ? () => widget.onVoiceSelected(voice.id)
                : null,
            onPreview: voice.isAvailable && voice.sampleText.isNotEmpty
                ? () => _playPreview(voice)
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
  final bool isLoading;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onPreview;

  const _VoiceCard({
    required this.voice,
    required this.isSelected,
    this.isLoading = false,
    this.isPlaying = false,
    this.onTap,
    this.onPreview,
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
                  : const Color(0xFFD4E8DC),
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
                if (onPreview != null) ...[
                  GestureDetector(
                    onTap: onPreview,
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? AppColors.primary.withValues(alpha: 0.15)
                            : AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: isLoading
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : Icon(
                              isPlaying
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                    ),
                  ),
                ],
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
                        color: const Color(0xFFD4E8DC),
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
