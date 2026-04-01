import 'dart:math' as math;
import 'package:flutter/material.dart';

enum VoiceState { idle, listening, processing, speaking }

class AIOrbWidget extends StatefulWidget {
  final VoiceState state;

  const AIOrbWidget({required this.state, super.key});

  @override
  State<AIOrbWidget> createState() => _AIOrbWidgetState();
}

class _AIOrbWidgetState extends State<AIOrbWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _rippleController;
  late AnimationController _waveformController;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _waveformController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    _rippleController.dispose();
    _waveformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _rotationController,
        _scaleController,
        _glowController,
        _pulseController,
        _rippleController,
        _waveformController,
      ]),
      builder: (context, child) {
        double scale = 1.0;
        double glowOpacity = 0.3;
        bool showRipple = false;
        bool showWaveform = false;

        switch (widget.state) {
          case VoiceState.idle:
            scale = 0.9 + 0.1 * _scaleController.value;
            glowOpacity = 0.3 + 0.2 * _glowController.value;
            break;
          case VoiceState.listening:
            scale = 1.0 + 0.2 * _pulseController.value;
            glowOpacity = 0.6 + 0.4 * _pulseController.value;
            break;
          case VoiceState.processing:
            showRipple = true;
            glowOpacity = 0.5;
            break;
          case VoiceState.speaking:
            showWaveform = true;
            glowOpacity = 0.7;
            break;
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            if (showRipple) _buildRippleEffect(),
            if (showWaveform) _buildWaveformEffect(),
            Transform.rotate(
              angle: _rotationController.value * 2 * math.pi,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF00FFFF).withValues(alpha: glowOpacity * 255),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: Color(0xFF8A2BE2).withValues(alpha: glowOpacity * 255),
                        blurRadius: 25,
                        spreadRadius: 3,
                      ),
                      BoxShadow(
                        color: Color(0xFFFF1493).withValues(alpha: glowOpacity * 255),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: OrbPainter(),
                    size: const Size(180, 180),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRippleEffect() {
    return SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(
        painter: RipplePainter(_rippleController.value),
      ),
    );
  }

  Widget _buildWaveformEffect() {
    return SizedBox(
      width: 180,
      height: 180,
      child: CustomPaint(
        painter: WaveformPainter(_waveformController.value),
      ),
    );
  }
}

class OrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final gradient = RadialGradient(
      center: Alignment.center,
      radius: 0.8,
      colors: [
        const Color(0xFF00FFFF), // cyan
        const Color(0xFF8A2BE2), // violet
        const Color(0xFFFF1493), // pink
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    // Create blob-like path
    final path = Path();
    const int segments = 16;
    const double variance = 0.1;

    for (int i = 0; i <= segments; i++) {
      double angle = (i / segments) * 2 * math.pi;
      double r = radius * (0.8 + variance * math.sin(angle * 3));
      Offset point = center + Offset(r * math.cos(angle), r * math.sin(angle));
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(path, paint);

    // Add inner highlight for 3D effect
    final highlightPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0x4DFFFFFF), Colors.transparent],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.7));

    canvas.drawCircle(center, radius * 0.7, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class RipplePainter extends CustomPainter {
  final double animationValue;

  RipplePainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      double progress = (animationValue + i * 0.3) % 1.0;
      double radius = progress * maxRadius * 1.5;
      double opacity = (1 - progress) * 0.5;

      final paint = Paint()
        ..color = Colors.cyan.withValues(alpha: opacity * 255)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class WaveformPainter extends CustomPainter {
  final double animationValue;

  WaveformPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    final paint = Paint()
      ..color = const Color(0xB2FF1493)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    const int waves = 6;
    for (int i = 0; i < waves; i++) {
      double angle = (i / waves) * 2 * math.pi + animationValue * 2 * math.pi;
      double radius = maxRadius * 0.8 + 20 * math.sin(animationValue * 2 * math.pi + i);
      Offset start = center + Offset(radius * math.cos(angle), radius * math.sin(angle));
      Offset end = center + Offset((radius + 30) * math.cos(angle), (radius + 30) * math.sin(angle));
      canvas.drawLine(start, end, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}