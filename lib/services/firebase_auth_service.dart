import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../firebase_options.dart';
import 'auth_service.dart';

class FirebaseAuthService {
  static bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
  static FirebaseAuth? get _auth =>
      isFirebaseInitialized ? FirebaseAuth.instance : null;
  static FirebaseFirestore? get _db =>
      isFirebaseInitialized ? FirebaseFirestore.instance : null;

  // ── Stream ──────────────────────────────────────────────────────────────────
  static Stream<User?> get authStateChanges {
    if (!isFirebaseInitialized) return const Stream.empty();
    return _auth!.authStateChanges();
  }

  static User? get currentUser {
    if (!isFirebaseInitialized) return null;
    return _auth?.currentUser;
  }

  // ── Save user to Firestore ──────────────────────────────────────────────────
  static Future<void> _saveUserToFirestore(User user,
      {String? displayName}) async {
    if (!isFirebaseInitialized || _db == null) return;
    try {
      final doc = _db!.collection('users').doc(user.uid);
      final snap = await doc.get();
      if (!snap.exists) {
        await doc.set({
          'uid': user.uid,
          'name': displayName ?? user.displayName ?? 'مستخدم',
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
          'provider': user.providerData.isNotEmpty
              ? user.providerData.first.providerId
              : 'email',
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        await doc.update({'lastLogin': FieldValue.serverTimestamp()});
      }
    } catch (e) {
      debugPrint('Firestore _saveUserToFirestore error: $e');
    }
  }

  // ── Get user profile from Firestore ────────────────────────────────────────
  static Future<Map<String, dynamic>?> getUserProfile() async {
    final user = currentUser;
    if (user == null || _db == null) return null;
    try {
      final doc = await _db!.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (e) {
      debugPrint('Firestore getUserProfile error: $e');
      return null;
    }
  }

  // ── Register with Email/Password ────────────────────────────────────────────
  static Future<({bool success, String message, User? user})>
      registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    if (!isFirebaseInitialized || _auth == null) {
      // Fallback to local storage if Firebase is not yet connected
      final local = await AuthService.register(
        name: name,
        email: email,
        password: password,
      );
      return (
        success: local.success,
        message: local.message,
        user: null,
      );
    }

    try {
      final credential = await _auth!.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await credential.user?.updateDisplayName(name.trim());
      await credential.user?.reload();
      if (credential.user != null) {
        await _saveUserToFirestore(credential.user!, displayName: name.trim());
        await AuthService.recordSavedAccount(
          id: credential.user!.uid,
          name: name.trim(),
          email: credential.user!.email ?? '',
          provider: 'firebase',
        );
      }
      return (
        success: true,
        message: 'تم إنشاء الحساب بنجاح! مرحباً ${name.trim()}',
        user: credential.user,
      );
    } on FirebaseAuthException catch (e) {
      return (
        success: false,
        message: _getErrorMessage(e.code),
        user: null,
      );
    } catch (e) {
      return (
        success: false,
        message: 'حدث خطأ أثناء إنشاء الحساب',
        user: null,
      );
    }
  }

  // ── Login with Email/Password ───────────────────────────────────────────────
  static Future<({bool success, String message, User? user})> loginWithEmail({
    required String email,
    required String password,
  }) async {
    if (!isFirebaseInitialized || _auth == null) {
      // Fallback to local storage if Firebase is not yet connected
      final local = await AuthService.login(
        email: email,
        password: password,
      );
      return (
        success: local.success,
        message: local.message,
        user: null,
      );
    }

    try {
      final credential = await _auth!.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (credential.user != null) {
        await _saveUserToFirestore(credential.user!);
        await AuthService.recordSavedAccount(
          id: credential.user!.uid,
          name: credential.user!.displayName ?? '',
          email: credential.user!.email ?? '',
          provider: 'firebase',
        );
      }
      return (
        success: true,
        message: 'مرحباً بعودتك!',
        user: credential.user,
      );
    } on FirebaseAuthException catch (e) {
      return (
        success: false,
        message: _getErrorMessage(e.code),
        user: null,
      );
    } catch (e) {
      return (
        success: false,
        message: 'حدث خطأ أثناء تسجيل الدخول',
        user: null,
      );
    }
  }

  // ── Google Sign-In ──────────────────────────────────────────────────────────
  static Future<({bool success, String message, User? user})>
      signInWithGoogle() async {
    if (!isFirebaseInitialized || _auth == null) {
      return (
        success: false,
        message:
            'يرجى إكمال إعداد ملف google-services.json لتفعيل تسجيل الدخول بجوجل',
        user: null,
      );
    }

    try {
      UserCredential userCredential;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await _auth!.signInWithPopup(googleProvider);
      } else {
        try {
          await GoogleSignIn.instance.initialize(
            serverClientId: DefaultFirebaseOptions.serverClientId,
          );
        } catch (_) {}

        final googleAccount = await GoogleSignIn.instance.authenticate();
        final googleAuth = googleAccount.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth!.signInWithCredential(credential);
      }

      if (userCredential.user != null) {
        await _saveUserToFirestore(userCredential.user!);
        await AuthService.recordSavedAccount(
          id: userCredential.user!.uid,
          name: userCredential.user!.displayName ?? '',
          email: userCredential.user!.email ?? '',
          avatarUrl: userCredential.user!.photoURL,
          provider: 'google',
        );
      }

      return (
        success: true,
        message:
            'تم تسجيل الدخول بجوجل! مرحباً ${userCredential.user?.displayName ?? ''}',
        user: userCredential.user,
      );
    } on FirebaseAuthException catch (e) {
      return (
        success: false,
        message: _getErrorMessage(e.code),
        user: null,
      );
    } catch (e) {
      return (
        success: false,
        message: 'حدث خطأ أثناء تسجيل الدخول بجوجل: $e',
        user: null,
      );
    }
  }

  // ── Update profile ──────────────────────────────────────────────────────────
  static Future<void> updateProfile({String? name, String? photoUrl}) async {
    final user = currentUser;
    if (user != null) {
      if (name != null) await user.updateDisplayName(name);
      if (photoUrl != null) await user.updatePhotoURL(photoUrl);
      if (_db != null) {
        final Map<String, dynamic> updates = {};
        if (name != null) updates['name'] = name;
        if (photoUrl != null) updates['photoUrl'] = photoUrl;
        if (updates.isNotEmpty) {
          await _db!.collection('users').doc(user.uid).update(updates);
        }
      }
    }
  }

  // ── Sign out ────────────────────────────────────────────────────────────────
  static Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (e) {
        debugPrint('GoogleSignIn signOut error: $e');
      }
    }
    if (isFirebaseInitialized && _auth != null) {
      try {
        await _auth!.signOut();
      } catch (e) {
        debugPrint('FirebaseAuth signOut error: $e');
      }
    }
  }

  // ── Error messages in Arabic ────────────────────────────────────────────────
  static String _getErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد الإلكتروني';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مسجل بالفعل!';
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'weak-password':
        return 'كلمة المرور ضعيفة، استخدم 6 أحرف على الأقل';
      case 'network-request-failed':
        return 'تحقق من اتصالك بالإنترنت';
      case 'too-many-requests':
        return 'محاولات كثيرة، حاول لاحقاً';
      case 'user-disabled':
        return 'هذا الحساب معطل';
      case 'invalid-credential':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      default:
        return 'حدث خطأ، يرجى المحاولة مجدداً ($code)';
    }
  }
}
