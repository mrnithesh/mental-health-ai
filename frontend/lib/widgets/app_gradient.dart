import 'package:flutter/material.dart';
import '../config/theme.dart';

class AppGradient extends StatelessWidget {
  final Widget child;
  final AppGradientType type;

  const AppGradient({
    super.key,
    required this.child,
    this.type = AppGradientType.primarySubtle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(gradient: type.gradient),
      child: child,
    );
  }
}

enum AppGradientType {
  primarySubtle,
  secondarySubtle,
  primaryBold,
  warmAccent,
  calmBackground;

  LinearGradient get gradient {
    switch (this) {
      case AppGradientType.primarySubtle:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.06),
            AppColors.background,
          ],
        );
      case AppGradientType.secondarySubtle:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.secondary.withValues(alpha: 0.06),
            AppColors.background,
          ],
        );
      case AppGradientType.primaryBold:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        );
      case AppGradientType.warmAccent:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.15),
            AppColors.secondary.withValues(alpha: 0.08),
          ],
        );
      case AppGradientType.calmBackground:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.04),
            AppColors.background,
            AppColors.secondary.withValues(alpha: 0.03),
          ],
        );
    }
  }
}
