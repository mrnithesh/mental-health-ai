import 'dart:math';
import 'package:flutter/material.dart';
import '../config/theme.dart';

class VoiceVisualizer extends StatefulWidget {
  final bool isPlaying;
  final bool isAnimated;
  final List<double> waveformData;
  final Duration duration;
  final VoidCallback onPlayPause;

  const VoiceVisualizer({
    required this.isPlaying,
    required this.isAnimated,
    required this.waveformData,
    required this.duration,
    required this.onPlayPause,
    super.key,
  });

  @override
  State<VoiceVisualizer> createState() => _VoiceVisualizerState();
}

class _VoiceVisualizerState extends State<VoiceVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: widget.onPlayPause,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              widget.isPlaying ? Icons.pause : Icons.play_arrow,
              key: ValueKey(widget.isPlaying),
              color: AppColors.primary,
              size: 24,
            ),
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 100,
          height: 24,
          child: AnimatedBuilder(
            animation: widget.isAnimated ? _animationController : AlwaysStoppedAnimation(0.0),
            builder: (context, child) {
              return CustomPaint(
                painter: WaveformPainter(
                  waveformData: widget.waveformData,
                  animationValue: widget.isAnimated ? _animationController.value : 1.0,
                  isAnimated: widget.isAnimated,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _formatDuration(widget.duration),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformData;
  final double animationValue;
  final bool isAnimated;

  WaveformPainter({
    required this.waveformData,
    required this.animationValue,
    required this.isAnimated,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;

    final barWidth = size.width / 20; // Fixed 20 bars
    final maxHeight = size.height;

    for (int i = 0; i < 20; i++) {
      double height = maxHeight * 0.1; // Minimum height

      if (waveformData.isNotEmpty) {
        final dataIndex = (i * waveformData.length / 20).floor();
        height = maxHeight * waveformData[dataIndex].clamp(0.0, 1.0);
      }

      if (isAnimated) {
        // Pulse effect
        final pulse = sin(animationValue * 2 * pi) * 0.3 + 0.7;
        height *= pulse;
      }

      final left = i * barWidth;
      final top = (maxHeight - height) / 2;
      final rect = Rect.fromLTWH(left, top, barWidth - 2, height);

      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.waveformData != waveformData ||
           oldDelegate.isAnimated != isAnimated;
  }
}