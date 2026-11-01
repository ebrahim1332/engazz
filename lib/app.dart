import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'screens/auth_screen.dart';
import 'services/firebase_auth_service.dart';
import 'services/auth_service.dart';

class EngazzApp extends StatelessWidget {
  const EngazzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Engazz · إنجاز',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F9B58),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF071911),
      ),
      home: const MainScreen(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // 1. Check Firebase Auth user
    if (FirebaseAuthService.currentUser != null) {
      if (mounted) {
        setState(() {
          _isLoggedIn = true;
          _isLoading = false;
        });
      }
      return;
    }

    // 2. Check local auth storage user
    final localUser = await AuthService.getCurrentUser();
    if (localUser != null) {
      if (mounted) {
        setState(() {
          _isLoggedIn = true;
          _isLoading = false;
        });
      }
      return;
    }

    // 3. Not logged in
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF071911),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F9B58), Color(0xFF1ED760)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1ED760).withValues(alpha: 0.35),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded, size: 44, color: Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'Engazz · إنجاز',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF1ED760),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoggedIn) {
      return const MainScreen();
    } else {
      return AuthScreen(
        onAuthSuccess: () {
          setState(() {
            _isLoggedIn = true;
          });
        },
      );
    }
  }
}
