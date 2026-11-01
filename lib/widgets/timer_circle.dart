import 'package:flutter/material.dart';
import '../painters/ring_painter.dart';
import 'timer_unit.dart';

/// الدايرة: البوردر المتحرك + خانات الساعة/الدقيقة/الثانية
class TimerCircle extends StatelessWidget {
  const TimerCircle({
    super.key,
    required this.animation,
    this.full = false,
    required this.seconds,
    required this.onChange,
    this.onSetValue,
  });

  /// أنيميشن البوردر
  final Animation<double> animation;

  /// البوردر كامل (التايمر واقف)
  final bool full;

  /// الثواني الباقية
  final ValueNotifier<int> seconds;

  final void Function(int unit, int delta) onChange;
  final void Function(int unit, int newValue)? onSetValue;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 20),
      height: 200,
      width: 200,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: CustomPaint(painter: RingPainter(animation, full)),
          ),
          ValueListenableBuilder<int>(
            valueListenable: seconds,
            builder: (context, total, _) => FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TimerUnit(
                      value: total ~/ 3600,
                      unit: 3600,
                      label: "HOUR",
                      onChange: onChange,
                      onSetValue: onSetValue,
                    ),
                    Text(
                      " : ",
                      style: TextStyle(fontSize: 30, color: Colors.green),
                    ),
                    TimerUnit(
                      value: (total % 3600) ~/ 60,
                      unit: 60,
                      label: "MIN",
                      onChange: onChange,
                      onSetValue: onSetValue,
                    ),
                    Text(
                      " : ",
                      style: TextStyle(fontSize: 30, color: Colors.green),
                    ),
                    TimerUnit(
                      value: total % 60,
                      unit: 1,
                      label: "SEC",
                      onChange: onChange,
                      onSetValue: onSetValue,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}