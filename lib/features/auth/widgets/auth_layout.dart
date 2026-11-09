import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// AutoRent logo: gradient rounded square with a car glyph.
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [
            BoxShadow(
              color: AppColors.brand.withValues(alpha: 0.45),
              blurRadius: size * 0.4,
              offset: Offset(0, size * 0.12),
            ),
          ],
        ),
        child: Icon(Icons.directions_car_filled_rounded,
            color: Colors.white, size: size * 0.52),
      );
}

/// Navy hero header + rounded sheet holding the form.
class AuthLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;
  final bool compactHeader;

  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
    this.compactHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.heroGradient),
        child: Stack(children: [
          // Decorative glows
          Positioned(
            top: -80,
            right: -60,
            child: _Glow(color: AppColors.brand.withValues(alpha: 0.35)),
          ),
          Positioned(
            top: 120,
            left: -90,
            child: _Glow(color: AppColors.info.withValues(alpha: 0.18)),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                        24, showBack ? 4 : 28, 24, compactHeader ? 22 : 34),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showBack)
                          IconButton(
                            padding: EdgeInsets.zero,
                            alignment: Alignment.centerLeft,
                            onPressed: () => Navigator.maybePop(context),
                            icon: const Icon(Icons.arrow_back_rounded,
                                color: Colors.white),
                          ),
                        if (!compactHeader) ...[
                          const AppLogo(size: 64),
                          const SizedBox(height: 22),
                        ],
                        Text(title,
                            style: context.text.headlineMedium
                                ?.copyWith(color: Colors.white)),
                        const SizedBox(height: 6),
                        Text(subtitle,
                            style: context.text.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.7))),
                      ],
                    ),
                  ),
                ),
                // The white sheet always reaches the bottom of the screen.
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.theme.scaffoldBackgroundColor,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    child: SafeArea(top: false, child: child),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final Color color;
  const _Glow({required this.color});

  @override
  Widget build(BuildContext context) => Container(
        width: 260,
        height: 260,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}
