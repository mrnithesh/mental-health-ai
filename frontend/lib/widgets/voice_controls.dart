import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';

enum VoiceState { idle, listening, recording }

class VoiceControlBar extends StatefulWidget {
  final VoidCallback onChatTap;
  final VoidCallback onMicTap;
  final VoidCallback onCancelTap;
  final VoiceState voiceState;

  const VoiceControlBar({
    required this.onChatTap,
    required this.onMicTap,
    required this.onCancelTap,
    required this.voiceState,
    super.key,
  });

  @override
  State<VoiceControlBar> createState() => _VoiceControlBarState();
}

class _VoiceControlBarState extends State<VoiceControlBar>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _chatScaleController;
  late AnimationController _micScaleController;
  late AnimationController _cancelScaleController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _chatScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _micScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _cancelScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _chatScaleController.dispose();
    _micScaleController.dispose();
    _cancelScaleController.dispose();
    super.dispose();
  }

  void _handleChatTap() {
    _chatScaleController.forward().then((_) => _chatScaleController.reverse());
    widget.onChatTap();
  }

  void _handleMicTap() {
    _micScaleController.forward().then((_) => _micScaleController.reverse());
    widget.onMicTap();
  }

  void _handleCancelTap() {
    _cancelScaleController.forward().then((_) => _cancelScaleController.reverse());
    widget.onCancelTap();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: AppSpacing.screenPadding,
      left: AppSpacing.screenPadding,
      right: AppSpacing.screenPadding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildChatButton(),
                _buildMicButton(),
                _buildCancelButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatButton() {
    return AnimatedBuilder(
      animation: _chatScaleController,
      builder: (context, child) {
        final scale = 1.0 - _chatScaleController.value * 0.2;
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: _handleChatTap,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMicButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _waveController]),
      builder: (context, child) {
        double scale = 1.0;
        double glowOpacity = 0.3;
        bool showWave = false;

        switch (widget.voiceState) {
          case VoiceState.idle:
            glowOpacity = 0.3;
            break;
          case VoiceState.listening:
            scale = 1.0 + 0.1 * _pulseController.value;
            glowOpacity = 0.6 + 0.4 * _pulseController.value;
            break;
          case VoiceState.recording:
            showWave = true;
            glowOpacity = 0.7;
            break;
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            if (showWave) _buildWaveEffect(),
            Transform.scale(
              scale: scale,
              child: AnimatedBuilder(
                animation: _micScaleController,
                builder: (context, child) {
                  final tapScale = 1.0 - _micScaleController.value * 0.2;
                  return Transform.scale(
                    scale: tapScale,
                    child: GestureDetector(
                      onTap: _handleMicTap,
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(glowOpacity),
                              AppColors.accent.withOpacity(glowOpacity),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(glowOpacity * 0.5),
                              blurRadius: 15,
                              spreadRadius: 2,
                            ),
                            BoxShadow(
                              color: AppColors.accent.withOpacity(glowOpacity * 0.3),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCancelButton() {
    return AnimatedBuilder(
      animation: _cancelScaleController,
      builder: (context, child) {
        final scale = 1.0 - _cancelScaleController.value * 0.2;
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: _handleCancelTap,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWaveEffect() {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(
        painter: WavePainter(_waveController.value),
      ),
    );
  }
}

class WavePainter extends CustomPainter {
  final double animationValue;

  WavePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const int waves = 4;
    for (int i = 0; i < waves; i++) {
      double progress = (animationValue + i * 0.25) % 1.0;
      double radius = 35 + progress * 15;
      double opacity = (1 - progress) * 0.8;

      paint.color = AppColors.primary.withOpacity(opacity);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}