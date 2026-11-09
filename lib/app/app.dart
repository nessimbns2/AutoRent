import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/services/theme_controller.dart';
import 'app_router.dart';
import 'routes.dart';
import 'theme.dart';

class AutoRentApp extends StatelessWidget {
  const AutoRentApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance.mode,
        builder: (context, mode, _) => MaterialApp(
          title: 'AutoRent',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          darkTheme: buildDarkTheme(),
          themeMode: mode,
          locale: const Locale('fr', 'FR'),
          supportedLocales: const [Locale('fr', 'FR'), Locale('en', 'US')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: Routes.splash,
          onGenerateRoute: AppRouter.onGenerateRoute,
          onUnknownRoute: AppRouter.onUnknownRoute,
          builder: (context, child) => _PhoneFrame(child: child!),
        ),
      );
}

/// On wide windows (desktop, tablet landscape) the app is rendered inside a
/// phone-sized frame so it always looks and behaves like a mobile app.
class _PhoneFrame extends StatelessWidget {
  final Widget child;
  const _PhoneFrame({required this.child});

  static const _phoneWidth = 420.0;
  static const _phoneHeight = 900.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= 560) return child;

    final height = math.min(mq.size.height - 40, _phoneHeight);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: dark ? const Color(0xFF04070D) : const Color(0xFFDCE1EB),
      child: Center(
        child: Container(
          width: _phoneWidth,
          height: height,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
                color: dark ? const Color(0xFF1E283A) : AppColors.ink,
                width: 6),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 40,
                  offset: Offset(0, 18)),
            ],
          ),
          child: MediaQuery(
            data: mq.copyWith(
              size: Size(_phoneWidth - 12, height - 12),
              padding: EdgeInsets.zero,
              viewPadding: EdgeInsets.zero,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
