import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
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

  late Future<_Data> _future = _load();
  bool _didChange = false;

  Future<_Data> _load() async {
    final m = await _maintenanceRepo.getById(widget.maintenanceId);
    final v = m == null ? null : await _vehicleRepo.getById(m.vehicleId);
    return _Data(m, v);
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _edit(Maintenance m) async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.maintenanceForm,
      arguments:
          MaintenanceFormArgs(maintenanceId: m.id, vehicleId: m.vehicleId),
    );
    if (saved == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  Future<void> _delete(Maintenance m) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer cet entretien ?',
      message: '${m.type} du ${formatDate(m.date)} sera supprimé.',
      confirmLabel: 'Supprimer',
    );
    if (ok != true || !mounted) return;
    await _maintenanceRepo.delete(m.id!);
    if (!mounted) return;
    showSnack(context, 'Entretien supprimé');
    Navigator.pop(context, true);
  }

  Future<void> _changeStatus(Maintenance m, MaintenanceStatus to) async {
    final ok = await confirmDialog(
      context,
      title: to == MaintenanceStatus.enCours
          ? "Démarrer l'entretien ?"
          : "Terminer l'entretien ?",
      message: to == MaintenanceStatus.enCours
          ? 'Le véhicule sera indisponible à la location pendant l\'intervention.'
          : 'Le véhicule redeviendra disponible à la location.',
      icon: to == MaintenanceStatus.enCours
          ? Icons.play_arrow_rounded
          : Icons.task_alt_rounded,
    );
    if (ok != true || !mounted) return;
    await _maintenanceRepo.changeStatus(m.id!, to);
    if (!mounted) return;
    showSnack(context, 'Statut mis à jour');
    _didChange = true;
    _reload();
  }

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
          if (snap.hasError || snap.data?.maintenance == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Entretien')),
              body: ErrorView(
                  error: snap.error ?? 'Entretien introuvable',
                  onRetry: _reload),
            );
          }
          final m = snap.data!.maintenance!;
          final vehicle = snap.data!.vehicle;
          final color = maintenanceStatusColor(m.status);

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context, _didChange),
              ),
              title: const Text('Entretien'),
              actions: [
                DetailMenu(items: [
                  DetailMenuItem(
                      'Modifier', Icons.edit_rounded, () => _edit(m)),
                  DetailMenuItem('Supprimer', Icons.delete_outline_rounded,
                      () => _delete(m),
                      destructive: true),
                ]),
                const SizedBox(width: 8),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                AppCard(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(children: [
                    IconBadge(
                        icon: maintenanceTypeIcon(m.type),
                        color: color,
                        size: 72),
                    const SizedBox(height: 12),
                    Text(m.type, style: context.text.headlineSmall),
                    const SizedBox(height: 6),
                    maintenanceStatusChip(m.status),
                    const SizedBox(height: 12),
                    Text(
                        '${formatLongDay(m.date)} ${m.date.year} · ${relativeDay(m.date)}',
                        style: context.text.bodySmall),
                  ]),
                ),
                if (vehicle != null)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 14),
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
                            Text('${vehicle.brand} ${vehicle.model}',
                                style: context.text.titleSmall),
                            Text(vehicle.plate, style: context.text.bodySmall),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: context.palette.muted),
                    ]),
                  ),
                SectionCard(
                  title: 'Informations',
                  icon: Icons.info_rounded,
                  iconColor: AppColors.info,
                  children: [
                    LabeledRow(
                        icon: Icons.category_outlined,
                        label: "Type d'intervention",
                        value: m.type),
                    LabeledRow(
                        icon: Icons.event_rounded,
                        label: 'Date prévue',
                        value: formatDate(m.date)),
                    LabeledRow(
                        icon: Icons.history_toggle_off_rounded,
                        label: 'Créé le',
                        value: formatDate(m.createdAt)),
                    if (m.description != null &&
                        m.description!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: context.palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(m.description!,
                            style: context.text.bodyMedium),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            bottomNavigationBar: switch (m.status) {
              MaintenanceStatus.planifie => BottomActionBar(
                  child: PrimaryButton(
                    label: "Démarrer l'entretien",
                    icon: Icons.play_arrow_rounded,
                    onPressed: () =>
                        _changeStatus(m, MaintenanceStatus.enCours),
                  ),
                ),
              MaintenanceStatus.enCours => BottomActionBar(
                  child: PrimaryButton(
                    label: "Terminer l'entretien",
                    icon: Icons.task_alt_rounded,
                    color: AppColors.success,
                    onPressed: () =>
                        _changeStatus(m, MaintenanceStatus.termine),
                  ),
                ),
              MaintenanceStatus.termine => null,
            },
          );
        },
      ),
    );
  }
}

class _Data {
  final Maintenance? maintenance;
  final Vehicle? vehicle;
  const _Data(this.maintenance, this.vehicle);
}
