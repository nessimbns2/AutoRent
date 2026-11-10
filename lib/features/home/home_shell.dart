import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/notifications/notification_service.dart';
import '../profile/account_tab.dart';
import '../rentals/rentals_tab.dart';
import '../services/services_tab.dart';
import '../vehicles/vehicles_tab.dart';
import 'dashboard_tab.dart';

/// Main authenticated screen: one page per tab + a floating bottom menu.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialTab.clamp(0, _items.length - 1);
  ServicesSegment _servicesSegment = ServicesSegment.maintenances;

  static const _items = [
    _NavItemData(
      Icons.space_dashboard_outlined,
      Icons.space_dashboard_rounded,
      'Accueil',
    ),
    _NavItemData(
      Icons.directions_car_outlined,
      Icons.directions_car_rounded,
      'Flotte',
    ),
    _NavItemData(
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      'Locations',
    ),
    _NavItemData(
      Icons.build_circle_outlined,
      Icons.build_circle_rounded,
      'Suivi',
    ),
    _NavItemData(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

  /// The urgent-alerts reminder is shown once per app session.
  static bool _alertShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _remindUrgent());
  }

  Future<void> _remindUrgent() async {
    if (_alertShown) return;
    _alertShown = true;
    await NotificationService.instance.refresh();
    final n = NotificationService.instance.urgentUnread.value;
    if (n == 0 || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        content: Row(
          children: [
            const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.brand,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                n == 1
                    ? '1 alerte urgente à traiter'
                    : '$n alertes urgentes à traiter',
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Voir',
          textColor: AppColors.brand,
          onPressed: () => Navigator.pushNamed(context, Routes.notifications),
        ),
      ),
    );
  }

  void _goTo(int i, {ServicesSegment? segment}) => setState(() {
    _index = i;
    if (segment != null) _servicesSegment = segment;
  });

  Widget _bodyFor(int i) => switch (i) {
    0 => DashboardTab(onGoToTab: _goTo),
    1 => const VehiclesTab(),
    2 => const RentalsTab(),
    3 => ServicesTab(initialSegment: _servicesSegment),
    _ => const AccountTab(),
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: Scaffold(
        // No cross-fade: it kept the old and new tab on screen together.
        body: KeyedSubtree(
          key: ValueKey('tab-$_index-${_servicesSegment.name}'),
          child: _bodyFor(_index),
        ),
        bottomNavigationBar: _FloatingNavBar(
          items: _items,
          index: _index,
          onTap: (i) => _goTo(i),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItemData(this.icon, this.activeIcon, this.label);
}

/// Frosted-glass floating menu: the active tab becomes a sunset-gradient
/// pill showing its label, the others show their icon only.
class _FloatingNavBar extends StatelessWidget {
  final List<_NavItemData> items;
  final int index;
  final ValueChanged<int> onTap;
  const _FloatingNavBar({
    required this.items,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    const radius = BorderRadius.all(Radius.circular(28));
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Color(0x400B1220),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                height: 70,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: dark
                        ? [const Color(0xE61A2238), const Color(0xF20F1626)]
                        : [const Color(0xEB1A2438), const Color(0xF50B1220)],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      _NavButton(
                        data: items[i],
                        selected: i == index,
                        onTap: () => onTap(i),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final inactive = Colors.white.withValues(alpha: 0.58);
    return Semantics(
      selected: selected,
      button: true,
      label: data.label,
      child: Tooltip(
        message: data.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            height: 48,
            padding: EdgeInsets.symmetric(horizontal: selected ? 16 : 12),
            decoration: BoxDecoration(
              gradient: selected ? AppColors.brandGradient : null,
              borderRadius: BorderRadius.circular(24),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.brand.withValues(alpha: 0.45),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? data.activeIcon : data.icon,
                  size: 22,
                  color: selected ? Colors.white : inactive,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            data.label,
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              height: 1.1,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
