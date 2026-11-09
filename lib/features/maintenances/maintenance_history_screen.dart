import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/maintenance.dart';
import '../../models/vehicle.dart';
import '../../repositories/maintenance_repository.dart';
import '../../repositories/vehicle_repository.dart';

class MaintenanceHistoryScreen extends StatefulWidget {
  final int vehicleId;
  const MaintenanceHistoryScreen({super.key, required this.vehicleId});

  @override
  State<MaintenanceHistoryScreen> createState() =>
      _MaintenanceHistoryScreenState();
}

class _MaintenanceHistoryScreenState extends State<MaintenanceHistoryScreen> {
  final _maintenanceRepo = MaintenanceRepository();
  final _vehicleRepo = VehicleRepository();

  late Future<_HistoryData> _future = _load();

  Future<_HistoryData> _load() async {
    final v = await _vehicleRepo.getById(widget.vehicleId);
    final list = await _maintenanceRepo.getByVehicle(widget.vehicleId);
    return _HistoryData(vehicle: v, maintenances: list);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _plan() async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.maintenanceForm,
      arguments: MaintenanceFormArgs(vehicleId: widget.vehicleId),
    );
    if (saved == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HistoryData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingView());
        }
        if (snap.hasError || snap.data?.vehicle == null) {
          return Scaffold(
            appBar: AppBar(title: const Text("Historique d'entretien")),
            body: ErrorView(
              error: snap.error ?? 'Véhicule introuvable',
              onRetry: _reload,
            ),
          );
        }
        final data = snap.data!;
        final vehicle = data.vehicle!;
        final list = data.maintenances;

        return Scaffold(
          appBar: AppBar(
            title: Text(vehicle.label),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(20),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  "Historique d'entretien",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _plan,
            child: const Icon(Icons.add),
          ),
          body: list.isEmpty
              ? const EmptyState(
                  message: 'Aucun entretien enregistré pour ce véhicule.')
              : RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ResponsiveCenter(
                    maxWidth: 850,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final m = list[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: const Icon(Icons.build_outlined, size: 20),
                            ),
                            title: Text(
                              m.type,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formatDate(m.date)),
                                if (m.description != null &&
                                    m.description!.isNotEmpty)
                                  Text(
                                    m.description!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                            trailing: maintenanceStatusChip(m.status),
                            onTap: () async {
                              final changed = await Navigator.pushNamed(
                                context,
                                Routes.maintenanceDetail,
                                arguments: IdArgs(m.id!),
                              );
                              if (changed == true && mounted) _reload();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class _HistoryData {
  final Vehicle? vehicle;
  final List<Maintenance> maintenances;
  _HistoryData({required this.vehicle, required this.maintenances});
}
