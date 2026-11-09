import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/incident.dart';
import '../../models/vehicle.dart';
import '../../repositories/incident_repository.dart';
import '../../repositories/vehicle_repository.dart';

class IncidentDetailScreen extends StatefulWidget {
  final int incidentId;
  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  final _incidentRepo = IncidentRepository();
  final _vehicleRepo = VehicleRepository();

  late Future<_IncidentDetailData> _future = _load();
  bool _didChange = false;

  Future<_IncidentDetailData> _load() async {
    final inc = await _incidentRepo.getById(widget.incidentId);
    Vehicle? v;
    if (inc != null) {
      v = await _vehicleRepo.getById(inc.vehicleId);
    }
    return _IncidentDetailData(incident: inc, vehicle: v);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _edit(Incident inc) async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.incidentForm,
      arguments: IncidentFormArgs(
        incidentId: inc.id,
        vehicleId: inc.vehicleId,
        rentalId: inc.rentalId,
      ),
    );
    if (saved == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  Future<void> _delete(Incident inc) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer incident',
      message: 'Voulez-vous vraiment supprimer définitivement cet incident ?',
      confirmLabel: 'Supprimer',
    );
    if (ok != true || !mounted) return;

    await _incidentRepo.delete(inc.id!);
    if (!mounted) return;
    showSnack(context, 'Incident supprimé');
    Navigator.pop(context, true);
  }

  Future<void> _changeStatus(Incident inc, IncidentStatus newStatus) async {
    final ok = await confirmDialog(
      context,
      title: 'Changer le statut',
      message: 'Passer cet incident à "${newStatus.label}" ?',
    );
    if (ok != true || !mounted) return;

    await _incidentRepo.changeStatus(inc.id!, newStatus);
    if (!mounted) return;
    showSnack(context, 'Statut mis à jour');
    _didChange = true;
    _reload();
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
      child: FutureBuilder<_IncidentDetailData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: LoadingView());
          }
          if (snap.hasError || snap.data?.incident == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Détail de l'incident")),
              body: ErrorView(
                error: snap.error ?? 'Incident introuvable',
                onRetry: _reload,
              ),
            );
          }
          final data = snap.data!;
          final inc = data.incident!;
          final vehicle = data.vehicle;
          final isAccident = inc.type == IncidentType.accident;

          return Scaffold(
            appBar: AppBar(
              title: Text('${inc.type.label} #${inc.id}'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context, _didChange),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _edit(inc),
                  tooltip: 'Modifier',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(inc),
                  tooltip: 'Supprimer',
                ),
              ],
            ),
            body: ResponsiveCenter(
              maxWidth: 850,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionCard(
                    title: 'Fiche incident',
                    children: [
                      Row(
                        children: [
                          Icon(
                            isAccident
                                ? Icons.car_crash_outlined
                                : Icons.build_outlined,
                            color: isAccident ? Colors.red : Colors.orange,
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            inc.type.label,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      isAccident ? Colors.red : Colors.orange,
                                ),
                          ),
                          const Spacer(),
                          incidentStatusChip(inc.status),
                        ],
                      ),
                      const Divider(height: 24),
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
                          subtitle: const Text('Véhicule concerné'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(
                            context,
                            Routes.vehicleDetail,
                            arguments: IdArgs(vehicle.id!),
                          ),
                        ),
                      if (inc.rentalId != null) ...[
                        const Divider(),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(
                              child: Icon(Icons.assignment_outlined)),
                          title: Text('Contrat de location #${inc.rentalId}'),
                          subtitle: const Text('Location liée'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pushNamed(
                            context,
                            Routes.rentalDetail,
                            arguments: IdArgs(inc.rentalId!),
                          ),
                        ),
                      ],
                      const Divider(),
                      LabeledRow(label: 'Date', value: formatDate(inc.date)),
                      LabeledRow(label: 'Lieu', value: inc.place),
                      LabeledRow(
                        label: 'Enregistré le',
                        value: formatDate(inc.createdAt),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Description :',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(inc.description),
                      ),
                    ],
                  ),
                  if (inc.photos.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Photos (${inc.photos.length})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    PhotoStrip(
                      fileNames: inc.photos,
                      onTap: (i) => _openPhotoViewer(inc.photos, i),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (inc.status == IncidentStatus.enAttente)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Prendre en charge'),
                        onPressed: () =>
                            _changeStatus(inc, IncidentStatus.enCours),
                      ),
                    ),
                  if (inc.status == IncidentStatus.enCours)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Marquer comme résolu'),
                        onPressed: () =>
                            _changeStatus(inc, IncidentStatus.resolu),
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

class _IncidentDetailData {
  final Incident? incident;
  final Vehicle? vehicle;
  _IncidentDetailData({required this.incident, required this.vehicle});
}
