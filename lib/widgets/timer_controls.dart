import 'package:flutter/material.dart';

/// أزرار التحكم: Start/Stop + End (بيظهر وقت التشغيل بس)
class TimerControls extends StatelessWidget {
  const TimerControls({
    super.key,
    required this.running,
    required this.onStartStop,
    required this.onEnd,
  });

  final bool running;
  final VoidCallback onStartStop;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton(
            onPressed: onStartStop,
            style: ElevatedButton.styleFrom(
              backgroundColor: running ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 48, vertical: 14),
            ),
            child: Text(
              running ? "Stop" : "Start",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (running) ...[
            SizedBox(width: 12),
            ElevatedButton(
              onPressed: onEnd,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              ),
              child: Text(
                "End",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
