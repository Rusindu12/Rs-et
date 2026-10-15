import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/common.dart';
import 'app_shell.dart';
import 'auth_screen.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool _showSplash = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1250), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return const _SplashScreen();
    return Consumer<AppState>(
      builder: (context, state, _) => state.profile == null
          ? const AuthScreen()
          : const AppShell(),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff7770FF), Color(0xff554CE0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: _controller, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Lottie.asset(
                    'assets/lottie/study_buddy.json',
                    width: 132,
                    height: 132,
                    repeat: true,
                    errorBuilder: (context, error, stackTrace) => const MascotBadge(size: 112),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'EduMate AI',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ඔබේ ඉගෙනුම් මිතුරා  •  Your study buddy',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                  ),
                  const SizedBox(height: 34),
                  SizedBox(
                    width: 106,
                    child: LinearProgressIndicator(
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(20),
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
