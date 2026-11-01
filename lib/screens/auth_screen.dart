import 'package:flutter/material.dart';
import '../services/firebase_auth_service.dart';
import '../services/storage_service.dart';
import 'main_screen.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback? onAuthSuccess;
  const AuthScreen({super.key, this.onAuthSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
            begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() => _isLogin = !_isLogin);
    _animCtrl.forward(from: 0.0);
  }

  void _closeToHome() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    }
  }

  void _handleSuccess([String? displayName]) {
    final name = (displayName != null && displayName.isNotEmpty)
        ? displayName
        : (_nameCtrl.text.isNotEmpty ? _nameCtrl.text : 'مستخدم');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text('مرحباً $name! تم تسجيل الدخول بنجاح'),
          ],
        ),
        backgroundColor: const Color(0xFF0F9B58),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    if (widget.onAuthSuccess != null) {
      widget.onAuthSuccess!();
    }
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        final res = await FirebaseAuthService.loginWithEmail(
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (res.success) {
          if (res.user != null) {
            await StorageService.syncAllFromFirestore();
          }
          _handleSuccess(res.user?.displayName);
        } else {
          _showError(res.message);
        }
      } else {
        final res = await FirebaseAuthService.registerWithEmail(
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (res.success) {
          if (res.user != null) {
            await StorageService.migrateGuestDataToUser(res.user!.uid);
            await StorageService.syncAllFromFirestore();
          }
          _handleSuccess(res.user?.displayName ?? _nameCtrl.text);
        } else {
          _showError(res.message);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('حدث خطأ غير متوقع');
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    try {
      final res = await FirebaseAuthService.signInWithGoogle();
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      if (res.success) {
        if (res.user != null) {
          await StorageService.migrateGuestDataToUser(res.user!.uid);
          await StorageService.syncAllFromFirestore();
        }
        _handleSuccess(res.user?.displayName);
      } else {
        _showError(res.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGoogleLoading = false);
      _showError('فشل تسجيل الدخول بجوجل');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF071911),
        body: SafeArea(
          child: Column(
            children: [
              // ── Top Bar with Close 'X' Button on Right ─────────────────────
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: IconButton(
                    tooltip: 'العودة للرئيسية',
                    onPressed: _closeToHome,
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                  // ── Logo / Brand ─────────────────────────────────────────
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F9B58), Color(0xFF1ED760)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF1ED760).withValues(alpha: 0.40),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.bolt_rounded,
                        size: 46, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Engazz · إنجاز',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isLogin
                        ? 'مرحباً بعودتك! سجّل دخولك لمتابعة إنجازاتك'
                        : 'أنشئ حسابك وابدأ في تنظيم وقتك وأهدافك',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 14),
                  ),
                  const SizedBox(height: 32),

                  // ── Form Card ───────────────────────────────────────────
                  FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF0E3827).withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Mode title inside card
                            Text(
                              _isLogin ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
                              style: const TextStyle(
                                color: Color(0xFF1ED760),
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Name (register only)
                            if (!_isLogin) ...[
                              _buildField(
                                ctrl: _nameCtrl,
                                label: 'الاسم بالكامل',
                                hint: 'مثال: محمد أحمد',
                                icon: Icons.person_outline_rounded,
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'يرجى إدخال الاسم'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                            ],

                            // Email
                            _buildField(
                              ctrl: _emailCtrl,
                              label: 'البريد الإلكتروني',
                              hint: 'example@email.com',
                              icon: Icons.email_outlined,
                              type: TextInputType.emailAddress,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'يرجى إدخال البريد الإلكتروني';
                                }
                                if (!v.contains('@') || !v.contains('.')) {
                                  return 'صيغة البريد غير صحيحة';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),

                            // Password
                            _buildField(
                              ctrl: _passwordCtrl,
                              label: 'كلمة المرور',
                              hint: '••••••••',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePassword,
                              suffix: _eyeButton(
                                _obscurePassword,
                                () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'يرجى إدخال كلمة المرور';
                                }
                                if (v.length < 6) {
                                  return 'يجب أن لا تقل عن 6 أحرف';
                                }
                                return null;
                              },
                            ),

                            // Confirm password (register only)
                            if (!_isLogin) ...[
                              const SizedBox(height: 14),
                              _buildField(
                                ctrl: _confirmCtrl,
                                label: 'تأكيد كلمة المرور',
                                hint: '••••••••',
                                icon: Icons.lock_reset_rounded,
                                obscure: _obscureConfirm,
                                suffix: _eyeButton(
                                  _obscureConfirm,
                                  () => setState(
                                      () => _obscureConfirm = !_obscureConfirm),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'يرجى تأكيد كلمة المرور';
                                  }
                                  if (v != _passwordCtrl.text) {
                                    return 'كلمات المرور غير متطابقة';
                                  }
                                  return null;
                                },
                              ),
                            ],

                            const SizedBox(height: 22),

                            // Submit Button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1ED760),
                                  foregroundColor: const Color(0xFF071911),
                                  elevation: 4,
                                  shadowColor: const Color(0xFF1ED760)
                                      .withValues(alpha: 0.4),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Color(0xFF071911)),
                                      )
                                    : Text(
                                        _isLogin
                                            ? 'تسجيل الدخول'
                                            : 'إنشاء الحساب',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Switch Mode ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin ? 'ليس لديك حساب؟' : 'لديك حساب بالفعل؟',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.65),
                            fontSize: 14),
                      ),
                      TextButton(
                        onPressed: _switchMode,
                        child: Text(
                          _isLogin ? 'إنشاء حساب' : 'تسجيل الدخول',
                          style: const TextStyle(
                              color: Color(0xFF1ED760),
                              fontWeight: FontWeight.bold,
                              fontSize: 15),
                        ),
                      ),
                    ],
                  ),

                  // ── Divider ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.15))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('أو',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 14)),
                      ),
                      Expanded(
                          child: Divider(
                              color: Colors.white.withValues(alpha: 0.15))),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Google Sign-In Button ─────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _isGoogleLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1.5),
                        backgroundColor:
                            Colors.white.withValues(alpha: 0.06),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isGoogleLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Image.network(
                                  'https://www.google.com/favicon.ico',
                                  width: 22,
                                  height: 22,
                                  errorBuilder: (context, error, stackTrace) => const Icon(
                                      Icons.g_mobiledata_rounded,
                                      color: Colors.white,
                                      size: 28),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'المتابعة بحساب جوجل',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  ),
),
);
  }

  Widget _buildField({
    required TextEditingController ctrl,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType type = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          keyboardType: type,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.white.withValues(alpha: 0.28)),
            filled: true,
            fillColor: Colors.black.withValues(alpha: 0.2),
            prefixIcon: Icon(icon, color: const Color(0xFF1ED760), size: 20),
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(14)),
                borderSide:
                    BorderSide(color: Color(0xFF1ED760), width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.redAccent)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide:
                    const BorderSide(color: Colors.redAccent, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _eyeButton(bool obscure, VoidCallback onTap) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: Colors.white54,
        size: 20,
      ),
      onPressed: onTap,
    );
  }
}
