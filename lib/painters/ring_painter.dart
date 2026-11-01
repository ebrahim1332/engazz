import 'dart:math' as math;

import 'package:flutter/material.dart';

/// بيرسم البوردر: خط رمادي خفيف كامل + قوس أخضر بيقل مع الوقت
class RingPainter extends CustomPainter {
  RingPainter(this.animation, [this.full = false]) : super(repaint: animation);

  final Animation<double> animation;
  final bool full;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final ring = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: (size.shortestSide - stroke) / 2,
    );

    canvas.drawCircle(
      ring.center,
      ring.width / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = Colors.green.shade100,
    );

    canvas.drawArc(
      ring,
      -math.pi / 2,
      2 * math.pi * (full ? 1.0 : animation.value),
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = Colors.green,
    );
  }

  @override
  bool shouldRepaint(RingPainter old) =>
      old.full != full || old.animation.value != animation.value;
}
