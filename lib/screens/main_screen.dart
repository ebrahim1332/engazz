import 'dart:async';
import 'package:flutter/material.dart';
import 'days_page.dart';
import 'home_screen.dart';
import 'planning_page.dart';
import 'analytics_page.dart';
import 'auth_screen.dart';
import 'profile_page.dart';
import '../services/firebase_auth_service.dart';
import '../services/auth_service.dart';
import '../services/storage_service.dart';
import '../services/app_config_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  /// Global controller to switch tab from any sub-widget if needed
  static void switchTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainScreenState>();
    state?.setTab(index);
  }

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  int _analyticsKey = 0;
  Timer? _usageSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppConfigService.onAppResumed();
    _currentIndex = widget.initialIndex;
    _runStartupChecks();

    // مزامنة وقت الاستخدام كل 10 دقائق فقط لتوفير الكوتا لأقصى درجة (أو عند إغلاق التطبيق)
    _usageSyncTimer = Timer.periodic(const Duration(minutes: 10), (_) {
      AppConfigService.flushUsageTime();
    });
  }

  @override
  void dispose() {
    _usageSyncTimer?.cancel();
    AppConfigService.onAppPaused();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AppConfigService.onAppResumed();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      AppConfigService.onAppPaused();
    }
  }

  Future<void> _runStartupChecks() async {
    // 0. تسجيل تثبيت/تنزيل التطبيق تلقائياً (مرة واحدة لكل جهاز)
    AppConfigService.recordAppInstall();

    if (FirebaseAuthService.currentUser != null) {
      AppConfigService.recordUserActivity();
      StorageService.syncAllFromFirestore().then((_) {
        if (mounted) setState(() {});
      });

      // 1. فحص حظر المستخدم
      final ban = await AppConfigService.checkBanStatus();
      if (ban.isBanned && mounted) {
        AppConfigService.showBannedDialog(context, ban.banReason);
        return;
      }
    }

    // 2. فحص التحديث الإجباري
    final update = await AppConfigService.checkAppUpdate();
    if (update != null && mounted) {
      AppConfigService.showForceUpdateDialog(context, update);
    }
  }

  void setTab(int index) {
    if (index >= 0 && index < 4) {
      setState(() {
        _currentIndex = index;
        if (index == 3) {
          _analyticsKey++;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DaysPage(),
      const HomeScreen(),
      const PlanningPage(),
      AnalyticsPage(key: ValueKey(_analyticsKey)),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF071911),
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          // ── Floating Profile Icon ────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, right: 12),
                child: _ProfileIconButton(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0E3827), Color(0xFF0F9B58)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F9B58).withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.calendar_today_rounded,
                label: 'أيامي',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.alarm_add_rounded,
                label: 'الجلسات',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.auto_awesome_rounded,
                label: 'التخطيط',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.insights_rounded,
                label: 'التحليلات',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF0F9B58) : Colors.white70,
              size: 22,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF0F9B58),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Floating Profile Icon Button
// ════════════════════════════════════════════════════════════════════════════

class _ProfileIconButton extends StatefulWidget {
  @override
  State<_ProfileIconButton> createState() => _ProfileIconButtonState();
}

class _ProfileIconButtonState extends State<_ProfileIconButton> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final localUser = await AuthService.getCurrentUser();
    if (localUser != null) {
      if (mounted) setState(() => _isLoggedIn = true);
      return;
    }
    final firebaseUser = FirebaseAuthService.currentUser;
    if (mounted) setState(() => _isLoggedIn = firebaseUser != null);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (_isLoggedIn) {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          );
          // Re-check login after returning (handles logout from profile)
          await _checkLogin();
        } else {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AuthScreen(onAuthSuccess: () {
                _checkLogin();
              }),
            ),
          );
          await _checkLogin();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isLoggedIn
              ? const Color(0xFF1ED760).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: _isLoggedIn
                ? const Color(0xFF1ED760).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          _isLoggedIn ? Icons.person_rounded : Icons.person_outline_rounded,
          color: _isLoggedIn ? const Color(0xFF1ED760) : Colors.white54,
          size: 22,
        ),
      ),
    );
  }
}
