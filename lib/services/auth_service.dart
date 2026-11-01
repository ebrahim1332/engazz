import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatarUrl': avatarUrl,
        'createdAt': createdAt.toIso8601String(),
      };

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatarUrl'] as String?,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

class AuthService {
  static const _currentUserKey = 'engazz_current_user';
  static const _usersKey = 'engazz_registered_users';

  /// جلب المستخدم الحالي المسجل دخوله إن وجد
  static Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_currentUserKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return UserModel.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// تعيين المستخدم النشط حالياً وحفظه
  static Future<void> setActiveUser({
    required String id,
    required String name,
    required String email,
    String? avatarUrl,
    String provider = 'local',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final user = UserModel(
      id: id,
      name: name.isNotEmpty ? name : 'مستخدم إنجاز',
      email: email,
      avatarUrl: avatarUrl,
      createdAt: DateTime.now(),
    );
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
    await recordSavedAccount(
      id: id,
      name: name,
      email: email,
      avatarUrl: avatarUrl,
      provider: provider,
    );
  }

  /// تسجيل حساب جديد
  static Future<({bool success, String message, UserModel? user})> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedName = name.trim();

    if (trimmedName.isEmpty) {
      return (success: false, message: 'يرجى إدخال اسم المستخدم', user: null);
    }
    if (trimmedEmail.isEmpty || !trimmedEmail.contains('@')) {
      return (
        success: false,
        message: 'يرجى إدخال بريد إلكتروني صحيح',
        user: null
      );
    }
    if (password.length < 6) {
      return (
        success: false,
        message: 'كلمة المرور يجب أن لا تقل عن 6 أحرف أو أرقام',
        user: null
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final usersRaw = prefs.getString(_usersKey);
    final usersList = usersRaw != null
        ? (jsonDecode(usersRaw) as List<dynamic>)
            .map((e) => e as Map<String, dynamic>)
            .toList()
        : <Map<String, dynamic>>[];

    // التحقق من وجود الحساب مسبقاً
    final exists = usersList.any(
      (u) => (u['email'] as String).toLowerCase() == trimmedEmail,
    );
    if (exists) {
      return (
        success: false,
        message: 'هذا البريد الإلكتروني مسجل بالفعل! يمكنك تسجيل الدخول',
        user: null
      );
    }

    final newUser = UserModel(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: trimmedName,
      email: trimmedEmail,
      createdAt: DateTime.now(),
    );

    usersList.add({
      ...newUser.toJson(),
      'password': password,
    });

    await prefs.setString(_usersKey, jsonEncode(usersList));
    await prefs.setString(_currentUserKey, jsonEncode(newUser.toJson()));
    await recordSavedAccount(
      id: newUser.id,
      name: newUser.name,
      email: newUser.email,
    );

    return (
      success: true,
      message: 'تم إنشاء الحساب بنجاح! مرحباً بك يا $trimmedName',
      user: newUser
    );
  }

  /// تسجيل الدخول
  static Future<({bool success, String message, UserModel? user})> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    if (trimmedEmail.isEmpty || password.isEmpty) {
      return (
        success: false,
        message: 'يرجى إدخال البريد الإلكتروني وكلمة المرور',
        user: null
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final usersRaw = prefs.getString(_usersKey);
    if (usersRaw == null) {
      return (
        success: false,
        message: 'لا يوجد حسابات مسجلة بعد، يمكنك إنشاء حساب جديد أولاً',
        user: null
      );
    }

    final usersList = (jsonDecode(usersRaw) as List<dynamic>)
        .map((e) => e as Map<String, dynamic>)
        .toList();

    final found = usersList.firstWhere(
      (u) =>
          (u['email'] as String).toLowerCase() == trimmedEmail &&
          u['password'] == password,
      orElse: () => {},
    );

    if (found.isEmpty) {
      return (
        success: false,
        message: 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
        user: null
      );
    }

    final user = UserModel.fromJson(found);
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
    await recordSavedAccount(
      id: user.id,
      name: user.name,
      email: user.email,
    );

    return (
      success: true,
      message: 'تم تسجيل الدخول بنجاح! مرحباً ${user.name}',
      user: user
    );
  }

  /// تسجيل الخروج
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  static const _savedAccountsKey = 'engazz_saved_accounts';

  /// تسجيل حساب في قائمة الحسابات المحفوظة للتبديل
  static Future<void> recordSavedAccount({
    required String id,
    required String name,
    required String email,
    String? avatarUrl,
    String provider = 'email',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedAccountsKey);
    final list = raw != null
        ? (jsonDecode(raw) as List<dynamic>)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
        : <Map<String, dynamic>>[];

    list.removeWhere((item) =>
        item['id'] == id || (email.isNotEmpty && item['email'] == email));
    list.insert(0, {
      'id': id,
      'name': name.isNotEmpty ? name : 'مستخدم إنجاز',
      'email': email,
      'avatarUrl': avatarUrl,
      'provider': provider,
      'lastUsed': DateTime.now().toIso8601String(),
    });

    await prefs.setString(_savedAccountsKey, jsonEncode(list));
  }

  /// جلب جميع الحسابات المحفوظة للتبديل
  static Future<List<Map<String, dynamic>>> getSavedAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_savedAccountsKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// التبديل إلى حساب محلي
  static Future<void> switchToLocalAccount(Map<String, dynamic> account) async {
    final prefs = await SharedPreferences.getInstance();
    final user = UserModel(
      id: account['id'] as String,
      name: account['name'] as String,
      email: account['email'] as String,
      avatarUrl: account['avatarUrl'] as String?,
      createdAt: DateTime.now(),
    );
    await prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
  }
}
