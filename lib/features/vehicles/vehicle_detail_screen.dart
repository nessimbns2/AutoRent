import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/vehicle.dart';
import '../../repositories/vehicle_repository.dart';

class VehicleDetailScreen extends StatefulWidget {
  final int vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final _repo = VehicleRepository();
  late Future<_VehicleDetailData> _future = _load();
  bool _didChange = false;

  Future<_VehicleDetailData> _load() async {
    final vehicle = await _repo.getById(widget.vehicleId);
    final availability = await _repo.getAvailabilityState(widget.vehicleId);
    return _VehicleDetailData(vehicle: vehicle, availability: availability);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _edit(Vehicle vehicle) async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.vehicleForm,
      arguments: VehicleFormArgs(vehicleId: vehicle.id),
    );
    if (saved == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  Future<void> _delete(Vehicle vehicle) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer véhicule',
      message: 'Voulez-vous vraiment supprimer ce véhicule ?',
      confirmLabel: 'Supprimer',
    );
    if (ok != true || !mounted) return;

    try {
      await _repo.delete(vehicle.id!);
      if (!mounted) return;
      showSnack(context, 'Véhicule supprimé');
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  Future<void> _rentVehicle(Vehicle vehicle) async {
    final changed = await Navigator.pushNamed(
      context,
      Routes.rentalForm,
      arguments: RentalFormArgs(vehicleId: vehicle.id),
    );
    if (changed == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  Future<void> _planMaintenance(Vehicle vehicle) async {
    final changed = await Navigator.pushNamed(
      context,
      Routes.maintenanceForm,
      arguments: MaintenanceFormArgs(vehicleId: vehicle.id),
    );
    if (changed == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  Future<void> _viewMaintenanceHistory(Vehicle vehicle) async {
    await Navigator.pushNamed(
      context,
      Routes.maintenanceHistory,
      arguments: IdArgs(vehicle.id!),
    );
    if (mounted) _reload();
  }

  void _openPhotoViewer(List<String> photos, int index) {
    Navigator.pushNamed(
      context,
      Routes.photoViewer,
      arguments: PhotoViewerArgs(fileNames: photos, initialIndex: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: FutureBuilder<_VehicleDetailData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: LoadingView());
          }
          if (snap.hasError || snap.data?.vehicle == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Détail véhicule')),
              body: ErrorView(
                error: snap.error ?? 'Véhicule introuvable',
                onRetry: _reload,
              ),
            );
          }
          final data = snap.data!;
          final vehicle = data.vehicle!;
          final avail = data.availability;
          final isRentable = avail == VehicleAvailability.disponible;

          return Scaffold(
            appBar: AppBar(
              title: Text(vehicle.label),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context, _didChange),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _edit(vehicle),
                  tooltip: 'Modifier',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(vehicle),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
            body: ResponsiveCenter(
              maxWidth: 900,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Photo banner or carousel
                  if (vehicle.photos.isNotEmpty) ...[
                    SizedBox(
                      height: 220,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: PageView.builder(
                          itemCount: vehicle.photos.length,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _openPhotoViewer(vehicle.photos, index),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CarImage(
                                    fileName: vehicle.photos[index],
                                    fit: BoxFit.cover,
                                  ),
                                  if (vehicle.photos.length > 1)
                                    Positioned(
                                      bottom: 8,
                                      right: 8,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${index + 1}/${vehicle.photos.length}',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PhotoStrip(
                      fileNames: vehicle.photos,
                      onTap: (i) => _openPhotoViewer(vehicle.photos, i),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    SizedBox(
                      height: 180,
                      width: double.infinity,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: const CarImage(fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  SectionCard(
                    title: 'Fiche technique',
                    children: [
                      LabeledRow(label: 'Marque', value: vehicle.brand),
                      LabeledRow(label: 'Modèle', value: vehicle.model),
                      LabeledRow(label: 'Immatriculation', value: vehicle.plate),
                      LabeledRow(
                        label: 'Tarif journalier',
                        value: formatMoney(vehicle.pricePerDay),
                      ),
                      LabeledRow(
                        label: 'État actuel',
                        value: '',
                        trailing: vehicleAvailabilityChip(avail),
                      ),
                      LabeledRow(
                        label: 'Interrupteur manuel',
                        value: vehicle.available ? 'Activé (1)' : 'Désactivé (0)',
                      ),
                      LabeledRow(
                        label: 'Ajouté le',
                        value: formatDate(vehicle.createdAt),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Actions
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.assignment),
                      label: const Text('Louer ce véhicule'),
                      onPressed: isRentable ? () => _rentVehicle(vehicle) : null,
                    ),
                  ),
                  if (!isRentable)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Center(
                        child: Text(
                          'Véhicule non disponible à la location (${avail.label})',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.build_outlined),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Planifier entretien'),
                          ),
                          onPressed: () => _planMaintenance(vehicle),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.history),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Historique entretien'),
                          ),
                          onPressed: () => _viewMaintenanceHistory(vehicle),
                        ),
                      ),
                    ],
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

class _VehicleDetailData {
  final Vehicle? vehicle;
  final VehicleAvailability availability;
  _VehicleDetailData({required this.vehicle, required this.availability});
}
