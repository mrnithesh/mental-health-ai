import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'voice_visualizer.dart';

class VoiceMessageBubble extends StatefulWidget {
  final List<double> waveformData;
  final Duration duration;
  final bool isUser;
  final bool isPlaying;
  final VoidCallback onPlayPause;

  const VoiceMessageBubble({
    required this.waveformData,
    required this.duration,
    required this.isUser,
    required this.isPlaying,
    required this.onPlayPause,
    super.key,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: widget.isUser ? const Offset(1.0, 0.0) : const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.md),
      child: Align(
        alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: widget.isUser
                ? Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: VoiceVisualizer(
                      isPlaying: widget.isPlaying,
                      isAnimated: false, // Static for recorded messages
                      waveformData: widget.waveformData,
                      duration: widget.duration,
                      onPlayPause: widget.onPlayPause,
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: VoiceVisualizer(
                      isPlaying: widget.isPlaying,
                      isAnimated: false, // Static for recorded messages
                      waveformData: widget.waveformData,
                      duration: widget.duration,
                      onPlayPause: widget.onPlayPause,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}