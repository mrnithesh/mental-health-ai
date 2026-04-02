import 'package:flutter/material.dart';

/// Brand mascot from assets. Use [withText] for splash and onboarding (includes "amigo" wordmark).
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    required this.size,
    this.withText = false,
    this.borderRadius,
    this.fit,
  });

  final double size;
  final bool withText;
  final double? borderRadius;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    final path =
        withText ? 'assets/images/logo_text.png' : 'assets/images/logo.png';
    final br = borderRadius ?? size * 0.28;
    final imageFit = fit ?? (withText ? BoxFit.contain : BoxFit.cover);
    return ClipRRect(
      borderRadius: BorderRadius.circular(br),
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: imageFit,
      ),
    );
  }
}

/// Small circular mascot for AI avatars and inline indicators.
class AppLogoCircle extends StatelessWidget {
  const AppLogoCircle({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
