import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'firebase_auth_service.dart';
import 'app_config_service.dart';
import '../screens/tasks.dart';
import '../screens/days_page.dart';

/// طبقة الحفظ والاسترجاع من الذاكرة المحلية والفايرستور
class StorageService {
  static const _daysKey = 'engazz_days';
  static const _sessionsKey = 'engazz_sessions';

  /// مفتاح مخصص لكل مستخدم لضمان فصل بيانات الحسابات
  static Future<String> getUserScopedKey(String baseKey) async {
    final activeUser = await AuthService.getCurrentUser();
    if (activeUser != null && activeUser.id.isNotEmpty) {
      return 'user_${activeUser.id}_$baseKey';
    }
    final fbUser = FirebaseAuthService.currentUser;
    if (fbUser != null && fbUser.uid.isNotEmpty) {
      return 'user_${fbUser.uid}_$baseKey';
    }
    return 'guest_$baseKey';
  }

  /// مزامنة البيانات في الخلفية مع فايرستور إن وجد اتصال بالإنترنت
  static Future<void> syncDocToFirestore(String docName, dynamic data) async {
    final fbUser = FirebaseAuthService.currentUser;
    if (fbUser == null || !FirebaseAuthService.isFirebaseInitialized) return;
    try {
      final db = FirebaseFirestore.instance;
      await db
          .collection('users')
          .doc(fbUser.uid)
          .collection('userData')
          .doc(docName)
          .set({
        'data': data,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('Firestore sync success: $docName for user ${fbUser.uid}');
    } catch (e) {
      debugPrint('Firestore sync error [$docName]: $e');
    }
  }

  /// جلب مستند من فايرستور
  static Future<dynamic> fetchDocFromFirestore(String docName) async {
    final fbUser = FirebaseAuthService.currentUser;
    if (fbUser == null || !FirebaseAuthService.isFirebaseInitialized) return null;
    try {
      final db = FirebaseFirestore.instance;
      final doc = await db
          .collection('users')
          .doc(fbUser.uid)
          .collection('userData')
          .doc(docName)
          .get();
      if (doc.exists && doc.data() != null) {
        debugPrint('Firestore fetch success: $docName');
        return doc.data()!['data'];
      }
    } catch (e) {
      debugPrint('Firestore fetch error [$docName]: $e');
    }
    return null;
  }

  /// جلب ومزامنة كافة بيانات المستخدم من فايرستور إلى الذاكرة المحلية عند تسجيل الدخول
  static Future<void> syncAllFromFirestore({bool force = false}) async {
    final fbUser = FirebaseAuthService.currentUser;
    if (fbUser == null || !FirebaseAuthService.isFirebaseInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final uid = fbUser.uid;

    final mapping = {
      'days': 'user_${uid}_$_daysKey',
      'sessions': 'user_${uid}_$_sessionsKey',
      'goals': 'user_${uid}_engazz_goals',
      'notes': 'user_${uid}_engazz_notes',
      'habits': 'user_${uid}_engazz_habits',
    };

    for (final entry in mapping.entries) {
      final docName = entry.key;
      final localKey = entry.value;

      try {
        final localData = prefs.getString(localKey);
        final hasLocal = localData != null && localData.isNotEmpty && localData != '[]';

        // إذا كان الجهاز الجديد لا يحتوي على بيانات أو طُلب فرض المزامنة
        if (!hasLocal || force) {
          final cloudData = await fetchDocFromFirestore(docName);
          if (cloudData != null) {
            await prefs.setString(localKey, jsonEncode(cloudData));
            debugPrint('Synced $docName from Firestore to local ($localKey)');
          }
        } else {
          // إذا كان الجهاز يحتوي على بيانات محلية ولكن الفايرستور فارغ (مثلاً بعد إنشاء الحساب مباشرة)
          final cloudData = await fetchDocFromFirestore(docName);
          if (cloudData == null || (cloudData is List && cloudData.isEmpty)) {
            final decoded = jsonDecode(localData);
            await syncDocToFirestore(docName, decoded);
            debugPrint('Uploaded local $docName to empty Firestore');
          }
        }
      } catch (e) {
        debugPrint('Error syncing $docName: $e');
      }
    }
  }

  /// نقل بيانات الزائر (guest) إلى الحساب الجديد تلقائياً عند إنشائه ورفعها للفايرستور
  static Future<void> migrateGuestDataToUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    const keys = [_daysKey, _sessionsKey, 'engazz_goals', 'engazz_notes', 'engazz_habits'];

    final docMap = {
      _daysKey: 'days',
      _sessionsKey: 'sessions',
      'engazz_goals': 'goals',
      'engazz_notes': 'notes',
      'engazz_habits': 'habits',
    };

    for (final baseKey in keys) {
      final guestKey = 'guest_$baseKey';
      final userKey = 'user_${userId}_$baseKey';

      final guestData = prefs.getString(guestKey);
      if (guestData != null && guestData.isNotEmpty && guestData != '[]') {
        final existingUserData = prefs.getString(userKey);
        if (existingUserData == null || existingUserData.isEmpty || existingUserData == '[]') {
          await prefs.setString(userKey, guestData);
          final docName = docMap[baseKey];
          if (docName != null) {
            try {
              final decoded = jsonDecode(guestData);
              await syncDocToFirestore(docName, decoded);
            } catch (_) {}
          }
        }
        await prefs.remove(guestKey);
      }
    }
  }

  // ── Days Save/Load ────────────────────────────────────────────────────────

  static Future<void> saveDays(List<DayModel> days) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await getUserScopedKey(_daysKey);
    final list = days.map((d) => _dayToJson(d)).toList();
    await prefs.setString(key, jsonEncode(list));
    syncDocToFirestore('days', list);
  }

  static Future<List<DayModel>> loadDays() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await getUserScopedKey(_daysKey);
    var raw = prefs.getString(key);

    // إذا كانت الذاكرة المحلية فارغة والمستخدم مسجل دخوله في فايربيز، نجلب من فايرستور
    if ((raw == null || raw == '[]') && FirebaseAuthService.currentUser != null) {
      final cloudData = await fetchDocFromFirestore('days');
      if (cloudData != null && cloudData is List && cloudData.isNotEmpty) {
        raw = jsonEncode(cloudData);
        await prefs.setString(key, raw);
      }
    }

    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => _dayFromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Sessions Save/Load ────────────────────────────────────────────────────

  /// يحفظ قائمة الجلسات مع التوقيت الزمني
  static Future<void> saveSessionModels(List<SessionModel> sessions) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await getUserScopedKey(_sessionsKey);
    final list = sessions.map((s) => s.toJson()).toList();
    await prefs.setString(key, jsonEncode(list));
    syncDocToFirestore('sessions', list);
    AppConfigService.recordUserActivity();
  }

  /// يحمّل قائمة الجلسات ككائنات SessionModel
  static Future<List<SessionModel>> loadSessionModels() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await getUserScopedKey(_sessionsKey);
    var raw = prefs.getString(key);

    // إذا كانت الذاكرة المحلية فارغة والمستخدم مسجل دخوله في فايربيز، نجلب من فايرستور
    if ((raw == null || raw == '[]') && FirebaseAuthService.currentUser != null) {
      final cloudData = await fetchDocFromFirestore('sessions');
      if (cloudData != null && cloudData is List && cloudData.isNotEmpty) {
        raw = jsonEncode(cloudData);
        await prefs.setString(key, raw);
      }
    }

    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => SessionModel.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// يحفظ قائمة الجلسات (توافقية)
  static Future<void> saveSessions(List<int> sessions) async {
    final models =
        sessions.map((s) => SessionModel(durationSeconds: s)).toList();
    await saveSessionModels(models);
  }

  /// يحمّل قائمة الجلسات بالثواني (توافقية)
  static Future<List<int>> loadSessions() async {
    final models = await loadSessionModels();
    return models.map((m) => m.durationSeconds).toList();
  }

  // ── Serialization ─────────────────────────────────────────────────────────

  static Map<String, dynamic> _dayToJson(DayModel d) => {
        'date': d.date.toIso8601String(),
        'note': d.note,
        'tasks': d.tasks.map(_taskToJson).toList(),
      };

  static DayModel _dayFromJson(Map<String, dynamic> m) => DayModel(
        date: DateTime.parse(m['date'] as String),
        note: m['note'] as String?,
        tasks: (m['tasks'] as List<dynamic>)
            .map((t) => _taskFromJson(t as Map<String, dynamic>))
            .toList(),
      );

  static Map<String, dynamic> _taskToJson(TaskModel t) => {
        'title': t.title,
        'hours': t.hours,
        'minutes': t.minutes,
        'seconds': t.seconds,
        'isCompleted': t.isCompleted,
      };

  static TaskModel _taskFromJson(Map<String, dynamic> m) => TaskModel(
        title: m['title'] as String,
        hours: m['hours'] as int,
        minutes: m['minutes'] as int,
        seconds: m['seconds'] as int,
        isCompleted: m['isCompleted'] as bool,
      );
}

/// كائن يمثل جلسة تركيز مع مدتها وتوقيتها الفعلي
class SessionModel {
  final int durationSeconds;
  final DateTime timestamp;

  SessionModel({
    required this.durationSeconds,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'duration': durationSeconds,
        'timestamp': timestamp.toIso8601String(),
      };

  factory SessionModel.fromJson(dynamic raw) {
    if (raw is int) {
      return SessionModel(durationSeconds: raw, timestamp: DateTime.now());
    } else if (raw is Map<String, dynamic>) {
      return SessionModel(
        durationSeconds: (raw['duration'] as num?)?.toInt() ?? 0,
        timestamp: raw['timestamp'] != null
            ? DateTime.tryParse(raw['timestamp'] as String) ?? DateTime.now()
            : DateTime.now(),
      );
    }
    return SessionModel(durationSeconds: 0, timestamp: DateTime.now());
  }
}
