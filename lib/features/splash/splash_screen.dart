import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/session/session_manager.dart';
import '../../core/widgets/shared_widgets.dart';
import '../auth/widgets/auth_layout.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _scale =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 1));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        SessionManager.instance.isLoggedIn ? Routes.home : Routes.login,
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AuroraBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(scale: _scale, child: const AppLogo(size: 96)),
              const SizedBox(height: 26),
              FadeTransition(
                opacity: _fade,
                child: Column(children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Auto',
                        style: context.text.headlineLarge
                            ?.copyWith(color: Colors.white, letterSpacing: -1)),
                    GradientText('Rent',
                        style: context.text.headlineLarge
                            ?.copyWith(color: Colors.white, letterSpacing: -1)),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    'Location de voitures, simplifiée',
                    style: context.text.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.6, color: AppColors.brand),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
