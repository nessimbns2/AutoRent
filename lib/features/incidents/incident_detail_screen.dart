import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
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

  late Future<_Data> _future = _load();
  bool _didChange = false;

  Future<_Data> _load() async {
    final view = await _incidentRepo.getViewById(widget.incidentId);
    final v = view == null
        ? null
        : await _vehicleRepo.getById(view.incident.vehicleId);
    return _Data(view, v);
  }

  void _reload() => setState(() { _future = _load(); });

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
      title: 'Supprimer cet incident ?',
      message: 'La déclaration et ses photos seront définitivement supprimées.',
      confirmLabel: 'Supprimer',
    );
    if (ok != true || !mounted) return;
    await _incidentRepo.delete(inc.id!);
    if (!mounted) return;
    showSnack(context, 'Incident supprimé');
    Navigator.pop(context, true);
  }

  Future<void> _changeStatus(Incident inc, IncidentStatus to) async {
    final ok = await confirmDialog(
      context,
      title: to == IncidentStatus.enCours
          ? 'Prendre en charge ?'
          : 'Marquer comme résolu ?',
      message: 'Le statut passera à « ${to.label} ».',
      icon: to == IncidentStatus.enCours
          ? Icons.engineering_rounded
          : Icons.verified_rounded,
    );
    if (ok != true || !mounted) return;
    await _incidentRepo.changeStatus(inc.id!, to);
    if (!mounted) return;
    showSnack(context, 'Statut mis à jour');
    _didChange = true;
    _reload();
  }

  void _openPhotos(List<String> photos, int index) => Navigator.pushNamed(
        context,
        Routes.photoViewer,
        arguments: PhotoViewerArgs(fileNames: photos, initialIndex: index),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _didChange);
      },
      child: FutureBuilder<_Data>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: LoadingView());
          }
          if (snap.hasError || snap.data?.view == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Incident')),
              body: ErrorView(
                  error: snap.error ?? 'Incident introuvable',
                  onRetry: _reload),
            );
          }
          final view = snap.data!.view!;
          final inc = view.incident;
          final vehicle = snap.data!.vehicle;
          final typeColor = incidentTypeColor(inc.type);

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context, _didChange),
              ),
              title: Text('${inc.type.label} #${inc.id}'),
              actions: [
                DetailMenu(items: [
                  DetailMenuItem(
                      'Modifier', Icons.edit_rounded, () => _edit(inc)),
                  DetailMenuItem('Supprimer', Icons.delete_outline_rounded,
                      () => _delete(inc),
                      destructive: true),
                ]),
                const SizedBox(width: 8),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        typeColor.withValues(alpha: 0.95),
                        typeColor.withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.lg + 4),
                  ),
                  child: Row(children: [
                    IconBadge(
                        icon: incidentTypeIcon(inc.type),
                        color: Colors.white,
                        size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inc.type.label,
                              style: context.text.titleLarge
                                  ?.copyWith(color: Colors.white)),
                          Text(
                              '${formatShortDate(inc.date)} · ${inc.place}',
                              style: context.text.bodySmall?.copyWith(
                                  color:
                                      Colors.white.withValues(alpha: 0.85))),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: inc.status.label,
                      color: Colors.white,
                    ),
                  ]),
                ),
                if (vehicle != null)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    onTap: () => Navigator.pushNamed(
                        context, Routes.vehicleDetail,
                        arguments: IdArgs(vehicle.id!)),
                    child: Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: CarImage(
                          fileName: vehicle.photos.isNotEmpty
                              ? vehicle.photos.first
                              : null,
                          seed: vehicle.id ?? 0,
                          width: 64,
                          height: 48,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Véhicule concerné',
                                style: context.text.bodySmall),
                            Text(
                                '${vehicle.brand} ${vehicle.model} · ${vehicle.plate}',
                                style: context.text.titleSmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: context.palette.muted),
                    ]),
                  ),
                if (inc.rentalId != null)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    onTap: () => Navigator.pushNamed(
                        context, Routes.rentalDetail,
                        arguments: IdArgs(inc.rentalId!)),
                    child: Row(children: [
                      const IconBadge(
                          icon: Icons.receipt_long_rounded,
                          color: AppColors.info,
                          size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Location liée',
                                style: context.text.bodySmall),
                            Text('Contrat #${inc.rentalId}',
                                style: context.text.titleSmall),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: context.palette.muted),
                    ]),
                  ),
                SectionCard(
                  title: 'Déclaration',
                  icon: Icons.description_rounded,
                  iconColor: typeColor,
                  children: [
                    LabeledRow(
                        icon: Icons.place_outlined,
                        label: 'Lieu',
                        value: inc.place),
                    LabeledRow(
                        icon: Icons.event_rounded,
                        label: 'Date',
                        value: formatDate(inc.date)),
                    LabeledRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Déclaré par',
                        value: view.reporterName ?? '—'),
                    LabeledRow(
                        icon: Icons.history_toggle_off_rounded,
                        label: 'Enregistré le',
                        value: formatDate(inc.createdAt)),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.palette.surfaceAlt,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child:
                          Text(inc.description, style: context.text.bodyMedium),
                    ),
                  ],
                ),
                if (inc.photos.isNotEmpty)
                  SectionCard(
                    title: 'Photos de constat (${inc.photos.length})',
                    icon: Icons.photo_library_rounded,
                    iconColor: AppColors.violet,
                    children: [
                      PhotoStrip(
                        fileNames: inc.photos,
                        size: 90,
                        onTap: (i) => _openPhotos(inc.photos, i),
                      ),
                    ],
                  ),
              ],
            ),
            bottomNavigationBar: switch (inc.status) {
              IncidentStatus.enAttente => BottomActionBar(
                  child: PrimaryButton(
                    label: 'Prendre en charge',
                    icon: Icons.engineering_rounded,
                    onPressed: () =>
                        _changeStatus(inc, IncidentStatus.enCours),
                  ),
                ),
              IncidentStatus.enCours => BottomActionBar(
                  child: PrimaryButton(
                    label: 'Marquer comme résolu',
                    icon: Icons.verified_rounded,
                    color: AppColors.success,
                    onPressed: () => _changeStatus(inc, IncidentStatus.resolu),
                  ),
                ),
              IncidentStatus.resolu => null,
            },
          );
        },
      ),
    );
  }
}

class _Data {
  final IncidentView? view;
  final Vehicle? vehicle;
  const _Data(this.view, this.vehicle);
}
