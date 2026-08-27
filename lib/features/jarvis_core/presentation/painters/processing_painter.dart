import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Paints particles converging toward the center plus rotating dashed rings.
///
/// [animationValue] (0 → 1, looping) drives both the particle inward
/// interpolation and the ring rotation.
class ProcessingPainter extends CustomPainter {
  ProcessingPainter({required this.animationValue});

  final double animationValue;

  static const int _particleCount = 24;
  static const int _ringCount = 3;

  // Seeded random for stable particle angles.
  static final _rng = math.Random(999);
  static final List<double> _angles = List.generate(
    _particleCount,
    (_) => _rng.nextDouble() * 2 * math.pi,
  );
  static final List<double> _speeds = List.generate(
    _particleCount,
    (_) => 0.4 + _rng.nextDouble() * 0.6,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // ── Rotating dashed rings ────────────────────────────────────────
    for (var r = 0; r < _ringCount; r++) {
      final radius = maxRadius * (0.35 + r * 0.2);
      final rotation = animationValue * 2 * math.pi * (r.isEven ? 1 : -1) * 0.5;
      final dashCount = 12 + r * 4;
      final dashArc = (2 * math.pi / dashCount) * 0.55;

      final paint = Paint()
        ..color = AppColors.tendaGold.withValues(alpha: 0.12 + 0.06 * r)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      for (var d = 0; d < dashCount; d++) {
        final startAngle = rotation + d * (2 * math.pi / dashCount);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          dashArc,
          false,
          paint,
        );
      }
    }

    // ── Converging particles ─────────────────────────────────────────
    for (var i = 0; i < _particleCount; i++) {
      final angle = _angles[i];
      final speed = _speeds[i];

      // Each particle loops from outer edge toward center.
      final t = (animationValue * speed * 2) % 1.0;
      // easeInCubic curve.
      final curved = Curves.easeInCubic.transform(t);
      final r = maxRadius * 0.9 * (1 - curved);

      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);

      final opacity = (1 - curved).clamp(0.0, 1.0) * 0.8;
      final radius = 2.0 + 2.0 * (1 - curved);

      final paint = Paint()
        ..color = AppColors.tendaGold.withValues(alpha: opacity);

      canvas.drawCircle(Offset(x, y), radius, paint);

      // Tiny trail.
      final trailR = r + maxRadius * 0.04;
      final tx = center.dx + trailR * math.cos(angle);
      final ty = center.dy + trailR * math.sin(angle);
      canvas.drawCircle(
        Offset(tx, ty),
        radius * 0.5,
        Paint()..color = AppColors.tendaGold.withValues(alpha: opacity * 0.3),
      );
    }

    // ── Central glow ─────────────────────────────────────────────────
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.tendaGoldLight.withValues(alpha: 0.9),
          AppColors.tendaGold.withValues(alpha: 0.2),
          AppColors.tendaGold.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.3, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 0.18));
    canvas.drawCircle(center, maxRadius * 0.18, glowPaint);

    canvas.drawCircle(
      center,
      maxRadius * 0.05,
      Paint()..color = AppColors.tendaWhite,
    );
  }

  @override
  bool shouldRepaint(ProcessingPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
