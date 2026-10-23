import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/maintenance.dart';
import '../../models/vehicle.dart';
import '../../repositories/maintenance_repository.dart';
import '../../repositories/vehicle_repository.dart';

class MaintenanceDetailScreen extends StatefulWidget {
  final int maintenanceId;
  const MaintenanceDetailScreen({super.key, required this.maintenanceId});

  @override
  State<MaintenanceDetailScreen> createState() =>
      _MaintenanceDetailScreenState();
}

class _MaintenanceDetailScreenState extends State<MaintenanceDetailScreen> {
  final _maintenanceRepo = MaintenanceRepository();
  final _vehicleRepo = VehicleRepository();

  late Future<_MaintenanceDetailData> _future = _load();
  bool _didChange = false;

  Future<_MaintenanceDetailData> _load() async {
    final m = await _maintenanceRepo.getById(widget.maintenanceId);
    Vehicle? v;
    if (m != null) {
      v = await _vehicleRepo.getById(m.vehicleId);
    }
    return _MaintenanceDetailData(maintenance: m, vehicle: v);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _edit(Maintenance m) async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.maintenanceForm,
      arguments: MaintenanceFormArgs(
        maintenanceId: m.id,
        vehicleId: m.vehicleId,
      ),
    );
    if (saved == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  Future<void> _delete(Maintenance m) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer entretien',
      message: 'Voulez-vous vraiment supprimer cet entretien ?',
      confirmLabel: 'Supprimer',
    );
    if (ok != true || !mounted) return;

    await _maintenanceRepo.delete(m.id!);
    if (!mounted) return;
    showSnack(context, 'Entretien supprimé');
    Navigator.pop(context, true);
  }

  Future<void> _changeStatus(Maintenance m, MaintenanceStatus newStatus) async {
    final ok = await confirmDialog(
      context,
      title: 'Changer le statut',
      message: 'Passer cet entretien à "${newStatus.label}" ?',
    );
    if (ok != true || !mounted) return;

    await _maintenanceRepo.changeStatus(m.id!, newStatus);
    if (!mounted) return;
    showSnack(context, 'Statut mis à jour');
    _didChange = true;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: FutureBuilder<_MaintenanceDetailData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: LoadingView());
          }
          if (snap.hasError || snap.data?.maintenance == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Détail de l'entretien")),
              body: ErrorView(
                error: snap.error ?? 'Entretien introuvable',
                onRetry: _reload,
              ),
            );
          }
          final data = snap.data!;
          final m = data.maintenance!;
          final vehicle = data.vehicle;

          return Scaffold(
            appBar: AppBar(
              title: const Text("Détail de l'entretien"),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context, _didChange),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _edit(m),
                  tooltip: 'Modifier',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(m),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
            body: ResponsiveCenter(
              maxWidth: 850,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                children: [
                  SectionCard(
                    title: 'Véhicule',
                    children: [
                      if (vehicle != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CarImage(
                              fileName: vehicle.photos.isNotEmpty
                                  ? vehicle.photos.first
                                  : null,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            vehicle.label,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text('Tarif : ${formatMoney(vehicle.pricePerDay)}/j'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(
                            context,
                            Routes.vehicleDetail,
                            arguments: IdArgs(vehicle.id!),
                          ),
                        )
                      else
                        const Text('Véhicule introuvable'),
                    ],
                  ),
                  SectionCard(
                    title: "Informations de l'intervention",
                    children: [
                      LabeledRow(label: 'Type', value: m.type),
                      LabeledRow(label: 'Date prévue', value: formatDate(m.date)),
                      LabeledRow(
                        label: 'Statut',
                        value: '',
                        trailing: maintenanceStatusChip(m.status),
                      ),
                      LabeledRow(
                        label: 'Créé le',
                        value: formatDate(m.createdAt),
                      ),
                      if (m.description != null && m.description!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Description :',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(m.description!),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (m.status == MaintenanceStatus.planifie)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text("Démarrer l'entretien"),
                        onPressed: () =>
                            _changeStatus(m, MaintenanceStatus.enCours),
                      ),
                    ),
                  if (m.status == MaintenanceStatus.enCours)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text("Terminer l'entretien"),
                        onPressed: () =>
                            _changeStatus(m, MaintenanceStatus.termine),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      ),
    );
  }
}

class _MaintenanceDetailData {
  final Maintenance? maintenance;
  final Vehicle? vehicle;
  _MaintenanceDetailData({required this.maintenance, required this.vehicle});
}
