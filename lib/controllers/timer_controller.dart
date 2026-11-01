import 'package:flutter/material.dart';
import '../services/storage_service.dart';

/// كل لوجيك التايمر: الوقت الباقي، التشغيل/الإيقاف، وجلسات اليوم
class TimerController extends ChangeNotifier {
  TimerController({required TickerProvider vsync}) {
    ctrl =
        AnimationController(
            vsync: vsync,
            duration: const Duration(seconds: 1),
            value: 1,
          )
          ..addListener(_updateNumbers)
          ..addStatusListener(_onDone);
    _loadSessions();
  }

  static const int maxSeconds = 359999; // 99:59:59

  /// أنيميشن البوردر (60 إطار/ثانية)
  late final AnimationController ctrl;

  /// الثواني الباقية
  final ValueNotifier<int> left = ValueNotifier(00 * 60);

  /// الوقت الكلي وقت التشغيل (0 = واقف)
  int start = 0;

  /// كائنات الجلسات مع التوقيت الفعلي
  final List<SessionModel> sessionModels = [];

  /// جلسات اليوم: مدة كل جلسة بالثواني (للتوافق مع الواجهة)
  List<int> get sessions =>
      sessionModels.map((s) => s.durationSeconds).toList();

  /// هل العد شغال دلوقتي؟
  bool get running => ctrl.isAnimating;

  /// الرقم بخانتين: 5 -> 05
  String two(int value) => value.toString().padLeft(2, '0');

  /// الوقت بصيغة 00:00:00
  String clock(int seconds) =>
      "${two(seconds ~/ 3600)}:${two((seconds % 3600) ~/ 60)}:${two(seconds % 60)}";

  /// اسم الجلسة: الأولى، الثانية، الثالثة...
  String sessionName(int index) {
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
    return "الجلسة ${index < names.length ? names[index] : index + 1}";
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _loadSessions() async {
    final saved = await StorageService.loadSessionModels();
    if (saved.isNotEmpty) {
      sessionModels.addAll(saved);
      notifyListeners();
    }
  }

  Future<void> _saveSessions() =>
      StorageService.saveSessionModels(sessionModels);

  // ── Internal ──────────────────────────────────────────────────────────────

  /// بيحدّث الأرقام كل ثانية (من غير rebuild للصفحة)
  void _updateNumbers() {
    if (start == 0) return;
    final seconds = (ctrl.value * start).ceil();
    if (seconds != left.value) left.value = seconds;
  }

  /// لما الوقت يخلص: الجلسة تتسجل والأرقام ترجع صفر والدايرة كاملة
  void _onDone(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      sessionModels.add(
          SessionModel(durationSeconds: start, timestamp: DateTime.now()));
      left.value = 0;
      start = 0;
      ctrl.value = 1;
      _saveSessions();
      notifyListeners();
    }
  }

  /// زيادة/نقصان الوقت: 3600 ساعة، 60 دقيقة، 1 ثانية
  void change(int unit, int delta) {
    ctrl.stop();
    left.value = (left.value + unit * delta).clamp(0, maxSeconds).toInt();
    start = 0;
    ctrl.value = 1;
    notifyListeners();
  }

  /// تعيين قيمة مباشرة للخانة (ساعة، دقيقة، ثانية)
  void setUnitValue(int unit, int newValue) {
    ctrl.stop();
    int h = left.value ~/ 3600;
    int m = (left.value % 3600) ~/ 60;
    int s = left.value % 60;

    if (unit == 3600) {
      h = newValue.clamp(0, 99);
    } else if (unit == 60) {
      m = newValue.clamp(0, 59);
    } else if (unit == 1) {
      s = newValue.clamp(0, 59);
    }

    left.value = (h * 3600 + m * 60 + s).clamp(0, maxSeconds);
    start = 0;
    ctrl.value = 1;
    notifyListeners();
  }

  /// Start / Stop: بيشغل العد أو بيوقفه مكانه
  void toggle() {
    if (running) {
      ctrl.stop();
    } else {
      if (left.value == 0) return;
      if (start == 0) {
        start = left.value;
        ctrl.value = 1;
      }
      ctrl.duration = Duration(seconds: start);
      ctrl.reverse();
    }
    notifyListeners();
  }

  /// إنهاء الجلسة بدري: بتتسجل في جلسات اليوم وتصفر الساعة
  void end() {
    final used = start - left.value;
    if (used > 0) {
      sessionModels.add(
          SessionModel(durationSeconds: used, timestamp: DateTime.now()));
    }
    ctrl.stop();
    left.value = 0;
    start = 0;
    ctrl.value = 1;
    _saveSessions();
    notifyListeners();
  }

  /// مسح جميع الجلسات
  void clearSessions() {
    sessionModels.clear();
    _saveSessions();
    notifyListeners();
  }

  @override
  void dispose() {
    ctrl.dispose();
    left.dispose();
    super.dispose();
  }
}