import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../repositories/rental_repository.dart';
import '../../repositories/incident_repository.dart';
import '../../repositories/vehicle_repository.dart';
import '../../app/routes.dart';
import '../../core/session/session_manager.dart';
import '../../core/widgets/shared_widgets.dart';

class DashboardTab extends StatefulWidget {
  final void Function(int tab) onGoToTab;
  const DashboardTab({super.key, required this.onGoToTab});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _rentalRepo = RentalRepository();
  final _incidentRepo = IncidentRepository();
  final _vehicleRepo = VehicleRepository();

  late Future<Map<String, int>> _future = _load();

  Future<Map<String, int>> _load() async {
    final user = SessionManager.instance.currentUser;
    final rentalCounts = await _rentalRepo.countByStatus(
      userId: user?.id,
      userEmail: user?.email,
    );
    final incidents = await _incidentRepo.getViewsByStatus(IncidentStatus.enAttente);
    final vehicles = await _vehicleRepo.getAll();

    return {
      'reservees': rentalCounts[RentalStatus.reservee] ?? 0,
      'en_cours': rentalCounts[RentalStatus.enCours] ?? 0,
      'incidents': incidents.length,
      'vehicles': vehicles.length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return ErrorView(
              error: snap.error!,
              onRetry: () => setState(() => _future = _load()));
        }
        final data = snap.data!;
        return RefreshIndicator(
          onRefresh: () async => setState(() => _future = _load()),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final int crossAxisCount = width >= 800 ? 4 : (width >= 550 ? 3 : 2);
              final double childAspectRatio = width < 360
                  ? 1.15
                  : (width < 550 ? 1.25 : 1.35);

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Tableau de bord',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: crossAxisCount,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: childAspectRatio,
                        children: [
                          _DashCard(
                            icon: Icons.assignment_outlined,
                            color: Colors.orange,
                            label: 'Locations réservées',
                            count: data['reservees']!,
                            onTap: () => widget.onGoToTab(2),
                          ),
                          _DashCard(
                            icon: Icons.drive_eta_outlined,
                            color: Colors.blue,
                            label: 'Locations en cours',
                            count: data['en_cours']!,
                            onTap: () => widget.onGoToTab(2),
                          ),
                          _DashCard(
                            icon: Icons.report_problem_outlined,
                            color: Colors.red,
                            label: 'Incidents en attente',
                            count: data['incidents']!,
                            onTap: () => widget.onGoToTab(4),
                          ),
                          _DashCard(
                            icon: Icons.directions_car_outlined,
                            color: Colors.green,
                            label: 'Véhicules',
                            count: data['vehicles']!,
                            onTap: () => widget.onGoToTab(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text('Actions rapides',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      _QuickAction(
                        icon: Icons.add_circle_outline,
                        label: 'Nouvelle location',
                        onTap: () async {
                          final changed = await Navigator.pushNamed(
                              context, Routes.rentalForm);
                          if (changed == true && mounted) {
                            setState(() => _future = _load());
                          }
                        },
                      ),
                      _QuickAction(
                        icon: Icons.report_outlined,
                        label: 'Déclarer un incident',
                        onTap: () async {
                          final changed = await Navigator.pushNamed(
                              context, Routes.incidentForm);
                          if (changed == true && mounted) {
                            setState(() => _future = _load());
                          }
                        },
                      ),
                      _QuickAction(
                        icon: Icons.build_outlined,
                        label: 'Planifier un entretien',
                        onTap: () async {
                          final changed = await Navigator.pushNamed(
                              context, Routes.maintenanceForm);
                          if (changed == true && mounted) {
                            setState(() => _future = _load());
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DashCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final int count;
  final VoidCallback onTap;
  const _DashCard(
      {required this.icon,
      required this.color,
      required this.label,
      required this.count,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$count',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon,
              color: Theme.of(context).colorScheme.primary),
          title: Text(label),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      );
}
