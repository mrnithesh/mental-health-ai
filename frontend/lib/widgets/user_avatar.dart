import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';

/// Circular user avatar that shows the Firebase photo if available,
/// otherwise a coloured initial badge.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.user,
    required this.size,
    this.displayName,
    this.borderColor,
    this.borderWidth = 0,
  });

  final User? user;
  final double size;

  /// Override displayed name for initial fallback (e.g. nickname).
  final String? displayName;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoURL;
    final name = displayName?.isNotEmpty == true
        ? displayName!
        : (user?.displayName ?? user?.email ?? '?');
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    Widget inner;
    if (photoUrl != null && photoUrl.isNotEmpty) {
      inner = ClipOval(
        child: Image.network(
          photoUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _InitialBadge(
            initial: initial,
            size: size,
          ),
        ),
      );
    } else {
      inner = _InitialBadge(initial: initial, size: size);
    }

    if (borderWidth > 0 && borderColor != null) {
      return Container(
        width: size + borderWidth * 2,
        height: size + borderWidth * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: borderWidth),
        ),
        child: ClipOval(child: SizedBox(width: size, height: size, child: inner)),
      );
    }

    return SizedBox(width: size, height: size, child: inner);
  }
}

class _InitialBadge extends StatelessWidget {
  const _InitialBadge({required this.initial, required this.size});
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
