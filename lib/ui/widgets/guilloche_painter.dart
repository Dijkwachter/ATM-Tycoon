import 'dart:math';

import 'package:flutter/material.dart';

/// Guilloche-cirkelpatroon voor de gele header (GDD 10): fijne, elkaar
/// overlappende cirkels zoals op een bankbiljet, subtiel donker op de
/// gradient.
class GuillochePainter extends CustomPainter {
  const GuillochePainter({this.opacity = 0.06});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = Colors.black.withValues(alpha: opacity);

    // Ringen van cirkels rond twee middelpunten geven het klassieke
    // vlechtwerk-effect.
    final centers = [
      Offset(size.width * 0.22, size.height * 0.4),
      Offset(size.width * 0.78, size.height * 0.65),
    ];
    for (final center in centers) {
      for (var i = 0; i < 14; i++) {
        final radius = 18.0 + i * 14;
        canvas.drawCircle(center, radius, paint);
      }
    }
    // Kleine satellietcirkels op een baan.
    final orbit = Offset(size.width * 0.5, size.height * 0.5);
    for (var i = 0; i < 24; i++) {
      final angle = i * pi / 12;
      final position =
          orbit + Offset(cos(angle) * size.width * 0.32, sin(angle) * 36);
      canvas.drawCircle(position, 22, paint);
    }
  }

  @override
  bool shouldRepaint(GuillochePainter oldDelegate) =>
      oldDelegate.opacity != opacity;
}
