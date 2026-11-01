import 'package:flutter/material.dart';
import 'session_item.dart';

/// Displays a list of sessions
class SessionsList extends StatelessWidget {
  final List<int> sessions;

  const SessionsList({
    required this.sessions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // sessionName can be determined by index directly
    // No need for TimerController - just use the index
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 84),
      itemCount: sessions.length,
      itemBuilder: (context, i) => SessionItem(
        label: _sessionName(i),
        seconds: sessions[i],
        isLast: i == sessions.length - 1,
      ),
    );
  }

  String _sessionName(int index) {
    const names = [
      "الأولى",
      "الثانية",
      "الثالثة",
      "الرابعة",
      "الخامسة",
      "السادسة",
      "السابعة",
      "الثامنة",
      "التاسعة",
      "العاشرة",
    ];
    return index < names.length ? names[index] : "الجلسة ${index + 1}";
  }
}