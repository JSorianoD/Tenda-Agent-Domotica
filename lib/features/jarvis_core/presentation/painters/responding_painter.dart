import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Paints 3 staggered expanding shockwaves radiating from the center.
///
/// Receives three animation values [wave1], [wave2], [wave3] — each driven
/// by its own [AnimationController] with staggered start times
/// (0 s / 0.72 s / 1.44 s via [Interval]).
class RespondingPainter extends CustomPainter {
  RespondingPainter({
    required this.wave1,
    required this.wave2,
    required this.wave3,
  });

  final double wave1;
  final double wave2;
  final double wave3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // ── Shockwaves ───────────────────────────────────────────────────
    _drawWave(canvas, center, maxRadius, wave1);
    _drawWave(canvas, center, maxRadius, wave2);
    _drawWave(canvas, center, maxRadius, wave3);

    // ── Central glow ─────────────────────────────────────────────────
    final pulse = 0.8 + 0.2 * math.sin(wave1 * math.pi * 2);
    final glowRadius = maxRadius * 0.2 * pulse;
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.tendaGoldLight.withValues(alpha: 0.95),
          AppColors.tendaGold.withValues(alpha: 0.4),
          AppColors.tendaGold.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: glowRadius));
    canvas.drawCircle(center, glowRadius, glowPaint);

    // Core dot.
    canvas.drawCircle(
      center,
      maxRadius * 0.06,
      Paint()..color = AppColors.tendaWhite,
    );
  }

  void _drawWave(Canvas canvas, Offset center, double maxRadius, double t) {
    if (t <= 0) return;
    final radius = maxRadius * 0.15 + maxRadius * 0.75 * t;
    final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.45;
    final strokeWidth = 2.5 * (1.0 - t * 0.6);

    final paint = Paint()
      ..color = AppColors.tendaGold.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, paint);

    // Secondary faint ring slightly outside.
    final outerPaint = Paint()
      ..color = AppColors.tendaGold.withValues(alpha: opacity * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.5;
    canvas.drawCircle(center, radius + 6, outerPaint);
  }

  @override
  bool shouldRepaint(RespondingPainter oldDelegate) =>
      oldDelegate.wave1 != wave1 ||
      oldDelegate.wave2 != wave2 ||
      oldDelegate.wave3 != wave3;
}
