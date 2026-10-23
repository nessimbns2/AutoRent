import 'package:flutter/material.dart';

import '../../core/widgets/app_drawer.dart';
import '../incidents/incidents_tab.dart';
import '../maintenances/maintenances_tab.dart';
import '../rentals/rentals_tab.dart';
import '../vehicles/vehicles_tab.dart';
import 'dashboard_tab.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _index = widget.initialTab;

  static const _titles = [
    'Accueil',
    'Véhicules',
    'Locations',
    'Entretiens',
    'Incidents',
  ];

  void _goTo(int i) => setState(() => _index = i);

  Widget _bodyFor(int i) => switch (i) {
        0 => DashboardTab(onGoToTab: _goTo),
        1 => const VehiclesTab(),
        2 => const RentalsTab(),
        3 => const MaintenancesTab(),
        _ => const IncidentsTab(),
      };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _index = 0);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 720;
          if (isWide) {
            return Scaffold(
              appBar: AppBar(title: Text(_titles[_index])),
              drawer: const AppDrawer(),
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _index,
                    onDestinationSelected: _goTo,
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.dashboard_outlined),
                        selectedIcon: Icon(Icons.dashboard),
                        label: Text('Accueil'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.directions_car_outlined),
                        selectedIcon: Icon(Icons.directions_car),
                        label: Text('Véhicules'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.assignment_outlined),
                        selectedIcon: Icon(Icons.assignment),
                        label: Text('Locations'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.build_outlined),
                        selectedIcon: Icon(Icons.build),
                        label: Text('Entretiens'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.report_problem_outlined),
                        selectedIcon: Icon(Icons.report_problem),
                        label: Text('Incidents'),
                      ),
                    ],
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(
                    child: KeyedSubtree(
                      key: ValueKey(_index),
                      child: _bodyFor(_index),
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            appBar: AppBar(title: Text(_titles[_index])),
            drawer: const AppDrawer(),
            body: KeyedSubtree(
              key: ValueKey(_index),
              child: _bodyFor(_index),
            ),
            bottomNavigationBar: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _index,
              onTap: _goTo,
              items: const [
                BottomNavigationBarItem(
                    icon: Icon(Icons.dashboard_outlined), label: 'Accueil'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.directions_car_outlined), label: 'Véhicules'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.assignment_outlined), label: 'Locations'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.build_outlined), label: 'Entretiens'),
                BottomNavigationBarItem(
                    icon: Icon(Icons.report_problem_outlined), label: 'Incidents'),
              ],
            ),
          );
        },
      ),
    );
  }
}
