import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_auth_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import 'main_screen.dart';
import 'auth_screen.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _firebaseUser;
  UserModel? _localUser;
  Map<String, dynamic>? _firestoreData;
  bool _isLoading = true;
  int _totalDays = 0;
  int _completedTasks = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      _firebaseUser = FirebaseAuthService.currentUser;
      _localUser = await AuthService.getCurrentUser();
      
      if (_firebaseUser != null) {
        _firestoreData = await FirebaseAuthService.getUserProfile();
      }

      // Load some user stats from StorageService
      final days = await StorageService.loadDays();
      int completed = 0;
      for (final day in days) {
        completed += day.tasks.where((t) => t.isCompleted).length;
      }

      if (mounted) {
        setState(() {
          _totalDays = days.length;
          _completedTasks = completed;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _displayName {
    if (_localUser?.name.isNotEmpty == true) {
      return _localUser!.name;
    }
    if (_firebaseUser?.displayName?.isNotEmpty == true) {
      return _firebaseUser!.displayName!;
    }
    if (_firestoreData?['name'] != null &&
        _firestoreData!['name'].toString().isNotEmpty) {
      return _firestoreData!['name'].toString();
    }
    return 'مستخدم إنجاز';
  }

  String get _displayEmail {
    if (_localUser?.email.isNotEmpty == true) {
      return _localUser!.email;
    }
    if (_firebaseUser?.email?.isNotEmpty == true) {
      return _firebaseUser!.email!;
    }
    return 'لا يوجد بريد إلكتروني';
  }

  String get _providerName {
    if (_firebaseUser != null && _firebaseUser!.providerData.isNotEmpty) {
      final pid = _firebaseUser!.providerData.first.providerId;
      if (pid.contains('google')) return 'Google';
      if (pid.contains('password')) return 'البريد الإلكتروني';
    }
    return 'حساب محلي';
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _displayName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0E3827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'تعديل الاسم',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'اكتب اسمك الجديد',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1ED760),
                foregroundColor: const Color(0xFF071911),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('حفظ', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _displayName) {
      setState(() => _isLoading = true);
      try {
        await FirebaseAuthService.updateProfile(name: newName);
      } catch (_) {}
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم تحديث الاسم بنجاح'),
            backgroundColor: const Color(0xFF0F9B58),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF0E3827),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'تسجيل الخروج',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('تسجيل الخروج'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF0E3827),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFF1ED760).withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Color(0xFF1ED760),
                      strokeWidth: 2.5,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'جاري تسجيل الخروج...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      try {
        await FirebaseAuthService.signOut();
      } catch (e) {
        debugPrint('Sign out error: $e');
      }
      try {
        await AuthService.logout();
      } catch (e) {
        debugPrint('AuthService logout error: $e');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF1ED760), size: 22),
              SizedBox(width: 10),
              Text(
                'تم تسجيل الخروج بنجاح',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF0A2419),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFF1ED760), width: 1),
          ),
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _showSwitchAccountModal() async {
    final accounts = await AuthService.getSavedAccounts();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF0A2419),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.switch_account_rounded, color: Color(0xFF1ED760), size: 24),
                  const SizedBox(width: 10),
                  const Text(
                    'تبديل الحساب',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (accounts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'لا توجد حسابات أخرى محفوظة على هذا الجهاز',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                )
              else
                ...accounts.map((acc) {
                  final email = acc['email'] ?? '';
                  final name = acc['name'] ?? 'مستخدم';
                  final isCurrent = email == _displayEmail;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFF1ED760).withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isCurrent
                            ? const Color(0xFF1ED760).withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isCurrent ? const Color(0xFF1ED760) : Colors.white24,
                        foregroundColor: isCurrent ? const Color(0xFF071911) : Colors.white,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'U',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        email.isNotEmpty ? email : 'حساب محلي',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                      ),
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1ED760))
                          : const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white38, size: 16),
                      onTap: isCurrent
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              await _performSwitchAccount(acc);
                            },
                    ),
                  );
                }),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                  },
                  icon: const Icon(Icons.person_add_rounded, color: Color(0xFF1ED760)),
                  label: const Text(
                    'تسجيل الدخول بحساب آخر',
                    style: TextStyle(color: Color(0xFF1ED760), fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF1ED760)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _performSwitchAccount(Map<String, dynamic> account) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF0E3827),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Color(0xFF1ED760), strokeWidth: 2.5),
                ),
                const SizedBox(width: 16),
                Text(
                  'جاري التبديل إلى ${account['name']}...',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // If current firebase user is different from target account, sign out from Firebase
    final currentFb = FirebaseAuthService.currentUser;
    if (currentFb != null && currentFb.uid != account['id']) {
      await FirebaseAuthService.signOut();
    }

    // Set target account as active user in AuthService
    await AuthService.setActiveUser(
      id: account['id'] as String,
      name: account['name'] as String,
      email: account['email'] as String,
      avatarUrl: account['avatarUrl'] as String?,
      provider: (account['provider'] as String?) ?? 'local',
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF1ED760), size: 20),
            const SizedBox(width: 10),
            Text(
              'تم التبديل إلى حساب ${account['name']}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0A2419),
        behavior: SnackBarBehavior.floating,
      ),
    );

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF071911),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'الملف الشخصي',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF1ED760)),
              tooltip: 'تعديل الاسم',
              onPressed: _editName,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF1ED760)),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // ── Avatar & Name Card ─────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0E3827), Color(0xFF0F9B58)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F9B58).withValues(alpha: 0.25),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1ED760).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 38,
                              color: Color(0xFF1ED760),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _displayEmail,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _providerName == 'Google'
                                      ? Icons.g_mobiledata_rounded
                                      : Icons.email_outlined,
                                  color: const Color(0xFF1ED760),
                                  size: 18,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'طريقة التسجيل: $_providerName',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Statistics Section ──────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.calendar_month_rounded,
                            title: 'الأيام المسجلة',
                            value: '$_totalDays',
                            color: const Color(0xFF1ED760),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.task_alt_rounded,
                            title: 'مهام مكتملة',
                            value: '$_completedTasks',
                            color: const Color(0xFF4FC3F7),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Account Details Card ────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E3827).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'معلومات الحساب',
                            style: TextStyle(
                              color: Color(0xFF1ED760),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildDetailRow(
                            icon: Icons.badge_outlined,
                            label: 'الاسم',
                            value: _displayName,
                            onTap: _editName,
                          ),
                          const Divider(color: Colors.white12, height: 20),
                          _buildDetailRow(
                            icon: Icons.alternate_email_rounded,
                            label: 'البريد الإلكتروني',
                            value: _displayEmail,
                          ),
                          const Divider(color: Colors.white12, height: 20),
                          _buildDetailRow(
                            icon: Icons.security_rounded,
                            label: 'نوع المصادقة',
                            value: _providerName,
                          ),
                          if (_firebaseUser?.uid != null) ...[
                            const Divider(color: Colors.white12, height: 20),
                            _buildDetailRow(
                              icon: Icons.fingerprint_rounded,
                              label: 'معرّف الحساب (UID)',
                              value: '${_firebaseUser!.uid.substring(0, 10)}...',
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Settings / Actions Card ─────────────────────────────
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E3827).withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildActionTile(
                            icon: Icons.switch_account_rounded,
                            title: 'تبديل الحساب',
                            subtitle: 'التبديل بين الحسابات المسجلة على هذا الجهاز',
                            titleColor: const Color(0xFF1ED760),
                            iconColor: const Color(0xFF1ED760),
                            onTap: _showSwitchAccountModal,
                          ),
                          const Divider(color: Colors.white12, height: 1),
                          _buildActionTile(
                            icon: Icons.logout_rounded,
                            title: 'تسجيل الخروج',
                            subtitle: 'الخروج من الحساب الحالي',
                            titleColor: Colors.redAccent,
                            iconColor: Colors.redAccent,
                            onTap: _logout,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0E3827).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: Colors.white60, size: 20),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.65),
                fontSize: 14,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              const Icon(Icons.edit, color: Color(0xFF1ED760), size: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    Color? titleColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? const Color(0xFF1ED760)).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? const Color(0xFF1ED760), size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
        ),
      ),
      trailing: trailing,
    );
  }
}
