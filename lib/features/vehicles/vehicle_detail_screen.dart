import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/rental.dart';
import '../../models/vehicle.dart';
import '../../repositories/rental_repository.dart';
import '../../repositories/vehicle_repository.dart';
import '../rentals/widgets/rental_tile.dart';

class VehicleDetailScreen extends StatefulWidget {
  final int vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final _repo = VehicleRepository();
  final _rentalRepo = RentalRepository();
  late Future<_VehicleDetailData> _future = _load();
  bool _didChange = false;
  int _photoIndex = 0;

  Future<_VehicleDetailData> _load() async {
    final vehicle = await _repo.getById(widget.vehicleId);
    final availability = await _repo.getAvailabilityState(widget.vehicleId);
    final stats = await _repo.getStats(widget.vehicleId);
    final rentals = await _rentalRepo.getViewsByVehicle(widget.vehicleId);
    return _VehicleDetailData(
      vehicle: vehicle,
      availability: availability,
      stats: stats,
      rentals: rentals.take(3).toList(),
    );
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _push(String route, Object? args) async {
    final changed = await Navigator.pushNamed(context, route, arguments: args);
    if (changed == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  Future<void> _delete(Vehicle vehicle) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer ce véhicule ?',
      message:
          '${vehicle.brand} ${vehicle.model} (${vehicle.plate}) sera définitivement supprimé.',
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _didChange);
      },
      child: FutureBuilder<_VehicleDetailData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Scaffold(body: LoadingView());
          }
          if (snap.hasError || snap.data?.vehicle == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Véhicule')),
              body: ErrorView(
                  error: snap.error ?? 'Véhicule introuvable',
                  onRetry: _reload),
            );
          }
          final data = snap.data!;
          final v = data.vehicle!;
          final avail = data.availability;
          final rentable = avail == VehicleAvailability.disponible;

          return Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  stretch: true,
                  backgroundColor: context.colors.surface,
                  leading: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Retour',
                      onPressed: () => Navigator.pop(context, _didChange),
                    ),
                  ),
                  leadingWidth: 64,
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: context.colors.surface,
                        shape: BoxShape.circle,
                        border: Border.all(color: context.palette.border),
                      ),
                      child: DetailMenu(items: [
                        DetailMenuItem('Modifier', Icons.edit_rounded,
                            () => _push(Routes.vehicleForm,
                                VehicleFormArgs(vehicleId: v.id))),
                        DetailMenuItem(
                            'Disponibilités',
                            Icons.calendar_month_rounded,
                            () => _push(Routes.availability, IdArgs(v.id!))),
                        DetailMenuItem('Supprimer',
                            Icons.delete_outline_rounded, () => _delete(v),
                            destructive: true),
                      ]),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _Gallery(
                      vehicle: v,
                      index: _photoIndex,
                      onChanged: (i) => setState(() => _photoIndex = i),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(v.brand.toUpperCase(),
                                      style: context.text.labelMedium?.copyWith(
                                          color: AppColors.brand,
                                          letterSpacing: 1.2)),
                                  Text(v.model,
                                      style: context.text.headlineSmall),
                                ],
                              ),
                            ),
                            vehicleAvailabilityChip(avail),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.badge_outlined,
                              size: 16, color: context.palette.muted),
                          const SizedBox(width: 6),
                          Text(v.plate, style: context.text.bodyMedium),
                          const SizedBox(width: 12),
                          Icon(Icons.event_outlined,
                              size: 16, color: context.palette.muted),
                          const SizedBox(width: 6),
                          Text('Ajouté le ${formatShortDate(v.createdAt)}',
                              style: context.text.bodySmall),
                        ]),
                        const SizedBox(height: 18),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 2.5,
                          children: [
                            InfoTile(
                                icon: Icons.payments_rounded,
                                label: 'Tarif / jour',
                                value: formatMoneyShort(v.pricePerDay)),
                            InfoTile(
                                icon: Icons.receipt_long_rounded,
                                label: 'Locations',
                                value: '${data.stats.rentals}',
                                color: AppColors.info),
                            InfoTile(
                                icon: Icons.savings_rounded,
                                label: 'Revenu généré',
                                value: formatMoneyShort(data.stats.revenue),
                                color: AppColors.success),
                            InfoTile(
                                icon: Icons.toggle_on_rounded,
                                label: 'Mise en location',
                                value: v.available ? 'Activée' : 'Désactivée',
                                color: v.available
                                    ? AppColors.teal
                                    : AppColors.danger),
                          ],
                        ),
                        if (!rentable) ...[
                          const SizedBox(height: 14),
                          InfoBanner(
                            icon: Icons.info_outline_rounded,
                            color: vehicleAvailabilityColor(avail),
                            text:
                                'Ce véhicule ne peut pas être loué pour le moment (${avail.label.toLowerCase()}).',
                          ),
                        ],
                        const SizedBox(height: 18),
                        SectionCard(
                          title: 'Entretien & sinistres',
                          icon: Icons.build_circle_rounded,
                          iconColor: AppColors.teal,
                          children: [
                            _ActionRow(
                              icon: Icons.history_rounded,
                              color: AppColors.teal,
                              label: "Historique d'entretien",
                              trailing: '${data.stats.maintenances}',
                              onTap: () => _push(
                                  Routes.maintenanceHistory, IdArgs(v.id!)),
                            ),
                            _ActionRow(
                              icon: Icons.event_repeat_rounded,
                              color: AppColors.warning,
                              label: 'Planifier un entretien',
                              onTap: () => _push(Routes.maintenanceForm,
                                  MaintenanceFormArgs(vehicleId: v.id)),
                            ),
                            _ActionRow(
                              icon: Icons.report_gmailerrorred_rounded,
                              color: AppColors.danger,
                              label: 'Déclarer un incident',
                              trailing: data.stats.incidents > 0
                                  ? '${data.stats.incidents}'
                                  : null,
                              onTap: () => _push(Routes.incidentForm,
                                  IncidentFormArgs(vehicleId: v.id)),
                            ),
                          ],
                        ),
                        if (data.rentals.isNotEmpty) ...[
                          const SectionHeader(title: 'Dernières locations'),
                          for (final r in data.rentals)
                            RentalTile(
                              view: r,
                              onTap: () => _push(
                                  Routes.rentalDetail, IdArgs(r.rental.id!)),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: BottomActionBar(
              child: Row(children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Prix', style: context.text.bodySmall),
                    Text.rich(TextSpan(children: [
                      TextSpan(
                          text: v.pricePerDay.toStringAsFixed(0),
                          style: context.text.headlineSmall
                              ?.copyWith(color: AppColors.brand)),
                      TextSpan(text: ' DT/j', style: context.text.bodySmall),
                    ])),
                  ],
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: PrimaryButton(
                    label: rentable ? 'Louer maintenant' : avail.label,
                    icon: rentable ? Icons.key_rounded : Icons.block_rounded,
                    onPressed: rentable
                        ? () => _push(Routes.rentalForm,
                            RentalFormArgs(vehicleId: v.id))
                        : null,
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  final Vehicle vehicle;
  final int index;
  final ValueChanged<int> onChanged;
  const _Gallery({
    required this.vehicle,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final photos = vehicle.photos;
    if (photos.isEmpty) {
      return Hero(
        tag: 'vehicle-${vehicle.id}',
        child: CarPlaceholder(seed: vehicle.id ?? 0, iconSize: 120),
      );
    }
    return Stack(fit: StackFit.expand, children: [
      PageView.builder(
        itemCount: photos.length,
        onPageChanged: onChanged,
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => Navigator.pushNamed(context, Routes.photoViewer,
              arguments: PhotoViewerArgs(fileNames: photos, initialIndex: i)),
          child: i == 0
              ? Hero(
                  tag: 'vehicle-${vehicle.id}',
                  child: CarImage(fileName: photos[i], seed: vehicle.id ?? 0))
              : CarImage(fileName: photos[i], seed: vehicle.id ?? 0),
        ),
      ),
      // Bottom fade for legibility
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.center,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Color(0x55000000)],
            ),
          ),
        ),
      ),
      if (photos.length > 1)
        Positioned(
          bottom: 14,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < photos.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == index ? 20 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ),
    ]);
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String? trailing;
  final VoidCallback onTap;
  const _ActionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            IconBadge(icon: icon, color: color, size: 38, iconSize: 19),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: context.text.bodyMedium)),
            if (trailing != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(trailing!, style: context.text.labelSmall),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: context.palette.muted),
          ]),
        ),
      );
}

class _VehicleDetailData {
  final Vehicle? vehicle;
  final VehicleAvailability availability;
  final VehicleStats stats;
  final List<RentalView> rentals;
  _VehicleDetailData({
    required this.vehicle,
    required this.availability,
    required this.stats,
    required this.rentals,
  });
}
