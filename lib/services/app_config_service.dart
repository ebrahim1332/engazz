import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_auth_service.dart';
import 'storage_service.dart';
import '../widgets/app_update_dialog.dart';

class UpdateInfo {
  final int latestVersionCode;
  final String latestVersionName;
  final bool isMandatory;
  final String downloadUrl;
  final String releaseNotes;
  final String title;

  UpdateInfo({
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.isMandatory,
    required this.downloadUrl,
    required this.releaseNotes,
    required this.title,
  });
}

class AppConfigService {
  /// رقم وإصدار التطبيق الحالي
  static const int currentVersionCode = 2;
  static const String currentVersionName = '1.0.1';

  static FirebaseFirestore? get _db =>
      FirebaseAuthService.isFirebaseInitialized ? FirebaseFirestore.instance : null;

  /// تسجيل تنزيل/تثبيت التطبيق لأول مرة (زيادة عداد التنزيلات تلقائياً في الفايربيز)
  static Future<void> recordAppInstall() async {
    if (_db == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasCounted = prefs.getBool('has_recorded_install_count') ?? false;
      if (!hasCounted) {
        await _db!.collection('app_config').doc('stats').set({
          'totalDownloads': FieldValue.increment(1),
          'lastInstallAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await prefs.setBool('has_recorded_install_count', true);
      }
    } catch (e) {
      debugPrint('recordAppInstall error: $e');
    }
  }

  /// تسجيل نشاط المستخدم وساعات التركيز الفعلية في قاعدة البيانات
  static Future<void> recordUserActivity() async {
    final user = FirebaseAuthService.currentUser;
    if (user == null || _db == null) return;
    try {
      final sessions = await StorageService.loadSessionModels();
      final totalSeconds = sessions.fold<int>(0, (total, s) => total + s.durationSeconds);
      final totalMinutes = (totalSeconds / 60).round();
      final totalHours = double.parse((totalSeconds / 3600.0).toStringAsFixed(1));

      final prefs = await SharedPreferences.getInstance();
      final usageSec = prefs.getInt('user_${user.uid}_total_usage_seconds') ?? totalSeconds;
      final usageMin = (usageSec / 60).round();
      final usageHours = double.parse((usageSec / 3600.0).toStringAsFixed(1));

      await _db!.collection('users').doc(user.uid).set({
        'lastActiveAt': FieldValue.serverTimestamp(),
        'appVersion': currentVersionName,
        'versionCode': currentVersionCode,
        'totalUsageSeconds': usageSec,
        'totalUsageMinutes': usageMin,
        'totalUsageHours': usageHours,
        'totalFocusSeconds': totalSeconds,
        'totalFocusMinutes': totalMinutes,
        'totalFocusHours': totalHours,
        'sessionsCount': sessions.length,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('recordUserActivity error: $e');
    }
  }

  // ── تتبع مدة استخدام التطبيق بالكامل (Screen Time Tracker) ──
  static DateTime? _sessionStartTime;

  /// عند فتح التطبيق أو العودة إليه من الخلفية
  static void onAppResumed() {
    _sessionStartTime = DateTime.now();
  }

  /// مزامنة دورية للوقت المنقضي أثناء فتح التطبيق
  static Future<void> flushUsageTime() async {
    if (_sessionStartTime == null) return;
    final now = DateTime.now();
    final elapsed = now.difference(_sessionStartTime!).inSeconds;
    if (elapsed >= 60) {
      _sessionStartTime = now;
      await _addUsageSeconds(elapsed);
    }
  }

  /// عند خروج المستخدم أو وضع التطبيق بالخلفية
  static Future<void> onAppPaused() async {
    if (_sessionStartTime == null) return;
    final now = DateTime.now();
    final elapsed = now.difference(_sessionStartTime!).inSeconds;
    _sessionStartTime = null;
    if (elapsed >= 5) {
      await _addUsageSeconds(elapsed);
    }
  }

  static Future<void> _addUsageSeconds(int seconds) async {
    final user = FirebaseAuthService.currentUser;
    if (user == null || _db == null || seconds <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'user_${user.uid}_total_usage_seconds';
      final currentTotal = (prefs.getInt(key) ?? 0) + seconds;
      await prefs.setInt(key, currentTotal);

      final totalMinutes = (currentTotal / 60).round();
      final totalHours = double.parse((currentTotal / 3600.0).toStringAsFixed(1));

      await _db!.collection('users').doc(user.uid).set({
        'totalUsageSeconds': currentTotal,
        'totalUsageMinutes': totalMinutes,
        'totalUsageHours': totalHours,
        'lastActiveAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('_addUsageSeconds error: $e');
    }
  }

  /// التحقق من حالة حظر المستخدم
  static Future<({bool isBanned, String banReason})> checkBanStatus() async {
    final user = FirebaseAuthService.currentUser;
    if (user == null || _db == null) return (isBanned: false, banReason: '');
    try {
      final doc = await _db!.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data['isBanned'] == true) {
          final reason = (data['banReason'] as String?)?.trim();
          return (
            isBanned: true,
            banReason: (reason != null && reason.isNotEmpty)
                ? reason
                : 'تم حظر هذا الحساب من قبل الإدارة لمخالفة شروط الاستخدام.',
          );
        }
      }
    } catch (e) {
      debugPrint('checkBanStatus error: $e');
    }
    return (isBanned: false, banReason: '');
  }

  /// التحقق من وجود تحديث إجباري للتطبيق
  static Future<UpdateInfo?> checkAppUpdate() async {
    if (_db == null) return null;
    try {
      final doc = await _db!.collection('app_config').doc('update').get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;

      final latestCode = (data['latestVersionCode'] as num?)?.toInt() ?? 1;
      final isMandatory = data['isMandatory'] == true;

      // يظهر فقط عند وجود إصدار أحدث ويكون التحديث إجبارياً
      if (latestCode > currentVersionCode && isMandatory) {
        return UpdateInfo(
          latestVersionCode: latestCode,
          latestVersionName: data['latestVersionName'] as String? ?? '1.0.1',
          isMandatory: isMandatory,
          downloadUrl: data['downloadUrl'] as String? ?? '',
          releaseNotes: data['releaseNotes'] as String? ?? 'تحسينات عامة وإصلاحات مهمة.',
          title: data['title'] as String? ?? 'تحديث جديد متاح لتطبيق إنجاز',
        );
      }
    } catch (e) {
      debugPrint('checkAppUpdate error: $e');
    }
    return null;
  }

  /// عرض دايلوج التحديث المباشر مع شريط تقدم وتثبيت تلقائي
  static void showForceUpdateDialog(BuildContext context, UpdateInfo update) {
    showDialog(
      context: context,
      barrierDismissible: !update.isMandatory,
      builder: (ctx) => AppUpdateDialog(update: update),
    );
  }

  /// عرض دايلوج الحظر (لا يمكن للمستخدم تجاوزه)
  static void showBannedDialog(BuildContext context, String reason) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: const Color(0xFF1E0A0A),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.redAccent, width: 2),
                    ),
                    child: const Icon(
                      Icons.block_rounded,
                      color: Colors.redAccent,
                      size: 42,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'تم حظر الحساب',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      reason,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () async {
                        await FirebaseAuthService.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
                        }
                      },
                      child: const Text('تسجيل الخروج'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
