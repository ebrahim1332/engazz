import 'package:flutter/material.dart';
import '../controllers/timer_controller.dart';
import '../widgets/timer_circle.dart';
import '../widgets/timer_controls.dart';
import '../widgets/sessions_list.dart';

// A widget that provides a TickerProvider for the TimerController
class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  TimerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = TimerController(vsync: this);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text("تأكيد"),
        content: const Text(
          "هل أنت متأكد من مسح جميع الجلسات؟",
          style: TextStyle(color: Colors.black, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("إلغاء"),
          ),
          TextButton(
            onPressed: () {
              _controller?.clearSessions();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("مسح"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 0,
        centerTitle: true,
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: const Text(
          "المؤقت وجلسات التركيز",
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: TimerCircle(
                animation: _controller!.ctrl,
                seconds: _controller!.left,
                onChange: _controller!.change,
                onSetValue: _controller!.setUnitValue,
              ),
            ),
            const SizedBox(height: 20),
            ListenableBuilder(
              listenable: _controller!,
              builder: (context, _) => TimerControls(
                running: _controller!.running,
                onStartStop: _controller!.toggle,
                onEnd: _controller!.end,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "جلسات اليوم",
                  style: TextStyle(
                    fontSize: 30,
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ListenableBuilder(
                  listenable: _controller!,
                  builder: (context, _) => IconButton(
                    onPressed: _controller!.sessions.isEmpty
                        ? null
                        : _showDeleteDialog,
                    icon: const Icon(Icons.delete_rounded),
                    color: Colors.red,
                    disabledColor: Colors.grey.shade300,
                    iconSize: 30,
                    tooltip: "مسح جميع الجلسات",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListenableBuilder(
                listenable: _controller!,
                builder: (context, _) =>
                    SessionsList(sessions: _controller!.sessions),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// The public HomeScreen widget
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
