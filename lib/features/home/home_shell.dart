import 'package:flutter/material.dart';

import '../../app/theme.dart';
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
    _NavItemData(Icons.space_dashboard_outlined, Icons.space_dashboard_rounded,
        'Accueil'),
    _NavItemData(Icons.directions_car_outlined, Icons.directions_car_rounded,
        'Flotte'),
    _NavItemData(Icons.receipt_long_outlined, Icons.receipt_long_rounded,
        'Locations'),
    _NavItemData(Icons.build_circle_outlined, Icons.build_circle_rounded,
        'Suivi'),
    _NavItemData(
        Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
  ];

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
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: dark ? AppColors.surfaceDark : AppColors.ink,
            borderRadius: BorderRadius.circular(26),
            border: dark ? Border.all(color: AppColors.borderDark) : null,
            boxShadow: const [
              BoxShadow(
                color: Color(0x330E1726),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    data: items[i],
                    selected: i == index,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
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
    final inactive = Colors.white.withValues(alpha: 0.55);
    return Semantics(
      selected: selected,
      button: true,
      label: data.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              // Not easeOutBack: its overshoot makes the shadow blur negative.
              curve: Curves.easeOutCubic,
              width: selected ? 52 : 40,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? AppColors.brand : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.brand.withValues(alpha: 0.45),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                selected ? data.activeIcon : data.icon,
                size: 22,
                color: selected ? Colors.white : inactive,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                height: 1.1,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : inactive,
              ),
              child: Text(data.label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}
