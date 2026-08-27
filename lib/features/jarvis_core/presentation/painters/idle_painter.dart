import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Paints concentric rings with oscillating opacity around a central glow.
///
/// The [animationValue] (0 → 1, repeating with reverse) drives the
/// opacity/scale breathing effect.
class IdlePainter extends CustomPainter {
  IdlePainter({required this.animationValue});

  final double animationValue;

  static const int _ringCount = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // ── Central glow ─────────────────────────────────────────────────
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.tendaGoldLight.withValues(alpha: 0.9),
          AppColors.tendaGold.withValues(alpha: 0.4),
          AppColors.tendaGold.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.35, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 0.25));

    canvas.drawCircle(center, maxRadius * 0.25, glowPaint);

    // ── Core dot ─────────────────────────────────────────────────────
    final corePaint = Paint()
      ..color = AppColors.tendaWhite.withValues(alpha: 0.95);
    canvas.drawCircle(center, maxRadius * 0.07, corePaint);

    // ── Concentric rings ─────────────────────────────────────────────
    for (var i = 0; i < _ringCount; i++) {
      final t = (i + 1) / (_ringCount + 1);
      final radius = maxRadius * (0.2 + t * 0.75);

      // Each ring breathes at a slightly offset phase.
      final phase = (animationValue + i * 0.12) % 1.0;
      final opacity = 0.08 + 0.18 * math.sin(phase * math.pi);

      final paint = Paint()
        ..color = AppColors.tendaGold.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(IdlePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
