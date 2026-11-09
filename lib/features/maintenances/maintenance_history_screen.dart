import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/maintenance.dart';
import '../../models/vehicle.dart';
import '../../repositories/maintenance_repository.dart';
import '../../repositories/vehicle_repository.dart';
import 'maintenances_tab.dart';

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
  bool _didChange = false;

  Future<_HistoryData> _load() async {
    final v = await _vehicleRepo.getById(widget.vehicleId);
    final list = await _maintenanceRepo.getByVehicle(widget.vehicleId);
    return _HistoryData(vehicle: v, maintenances: list);
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _open(String route, Object args) async {
    final saved = await Navigator.pushNamed(context, route, arguments: args);
    if (saved == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _didChange);
      },
      child: FutureBuilder<_HistoryData>(
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
                  onRetry: _reload),
            );
          }
          final vehicle = snap.data!.vehicle!;
          final list = snap.data!.maintenances;

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context, _didChange),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Historique d'entretien"),
                  Text('${vehicle.brand} ${vehicle.model} · ${vehicle.plate}',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () => _open(Routes.maintenanceForm,
                  MaintenanceFormArgs(vehicleId: widget.vehicleId)),
              icon: const Icon(Icons.event_repeat_rounded),
              label: const Text('Planifier'),
            ),
            body: list.isEmpty
                ? const EmptyState(
                    icon: Icons.history_rounded,
                    title: 'Aucun historique',
                    message: 'Aucun entretien enregistré pour ce véhicule.')
                : RefreshIndicator(
                    onRefresh: () async => _reload(),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
                      itemCount: list.length,
                      itemBuilder: (context, i) => MaintenanceTile(
                        showVehicle: false,
                        view: MaintenanceView(
                            maintenance: list[i],
                            vehicleLabel: vehicle.label),
                        onTap: () => _open(
                            Routes.maintenanceDetail, IdArgs(list[i].id!)),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _HistoryData {
  final Vehicle? vehicle;
  final List<Maintenance> maintenances;
  _HistoryData({required this.vehicle, required this.maintenances});
}
