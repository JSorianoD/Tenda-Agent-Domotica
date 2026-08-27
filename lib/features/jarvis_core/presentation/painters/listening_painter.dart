import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Paints 30 radial bars simulating audio-waveform amplitudes.
///
/// Uses a seeded [Random] so the pseudo-random bar heights are stable across
/// rebuilds (no visual "jumping").  [animationValue] (0 → 1, looping) drives
/// the per-bar oscillation.
class ListeningPainter extends CustomPainter {
  ListeningPainter({required this.animationValue});

  final double animationValue;

  static const int _barCount = 30;
  static const double _barWidthDeg = 6.0; // degrees

  // Seeded random — same sequence every time.
  static final _rng = math.Random(12345);
  static final List<double> _seeds = List.generate(
    _barCount,
    (_) => _rng.nextDouble(),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final innerRadius = maxRadius * 0.28;

    // ── Central glow ─────────────────────────────────────────────────
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          AppColors.tendaGoldLight.withValues(alpha: 0.95),
          AppColors.tendaGold.withValues(alpha: 0.3),
          AppColors.tendaGold.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius * 0.22));
    canvas.drawCircle(center, maxRadius * 0.22, glowPaint);

    // Core dot.
    canvas.drawCircle(
      center,
      maxRadius * 0.06,
      Paint()..color = AppColors.tendaWhite,
    );

    // ── Radial bars ──────────────────────────────────────────────────
    final barAngle = 2 * math.pi / _barCount;
    final barWidthRad = _barWidthDeg * math.pi / 180;

    for (var i = 0; i < _barCount; i++) {
      final angle = i * barAngle - math.pi / 2; // start at top

      // Per-bar amplitude driven by animation + seed offset.
      final seed = _seeds[i];
      final phase = (animationValue * 2 * math.pi) + (seed * 2 * math.pi);
      final amp = 0.3 + 0.7 * ((math.sin(phase) + 1) / 2) * seed;

      final outerRadius = innerRadius + (maxRadius - innerRadius) * 0.7 * amp;

      final rect = Rect.fromCircle(center: center, radius: outerRadius);
      final paint = Paint()
        ..color = AppColors.tendaGold.withValues(alpha: 0.5 + 0.5 * amp)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round;

      // Draw each bar as a short arc.
      canvas.drawArc(rect, angle - barWidthRad / 2, barWidthRad, false, paint);

      // Inner connection line.
      final innerX = center.dx + innerRadius * math.cos(angle);
      final innerY = center.dy + innerRadius * math.sin(angle);
      final outerX = center.dx + outerRadius * math.cos(angle);
      final outerY = center.dy + outerRadius * math.sin(angle);

      final linePaint = Paint()
        ..color = AppColors.tendaGold.withValues(alpha: 0.25 + 0.35 * amp)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(innerX, innerY),
        Offset(outerX, outerY),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(ListeningPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
