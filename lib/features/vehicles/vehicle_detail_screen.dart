import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/constants/business_rules.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/rental.dart';
import '../../models/vehicle.dart';
import '../../models/vehicle_document.dart';
import '../../repositories/rental_repository.dart';
import '../../repositories/vehicle_document_repository.dart';
import '../../repositories/vehicle_repository.dart';
import '../rentals/widgets/rental_tile.dart';
import 'vehicle_export_actions.dart';

class VehicleDetailScreen extends StatefulWidget {
  final int vehicleId;
  const VehicleDetailScreen({super.key, required this.vehicleId});

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  final _repo = VehicleRepository();
  final _rentalRepo = RentalRepository();
  final _docRepo = VehicleDocumentRepository();
  late Future<_VehicleDetailData> _future = _load();
  bool _didChange = false;
  int _photoIndex = 0;

  Future<_VehicleDetailData> _load() async {
    final vehicle = await _repo.getById(widget.vehicleId);
    final availability = await _repo.getAvailabilityState(widget.vehicleId);
    final stats = await _repo.getStats(widget.vehicleId);
    final rentals = await _rentalRepo.getViewsByVehicle(widget.vehicleId);
    final docs = await _docRepo.getByVehicle(widget.vehicleId);
    return _VehicleDetailData(
      vehicle: vehicle,
      availability: availability,
      stats: stats,
      rentals: rentals.take(3).toList(),
      documents: docs,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _push(String route, Object? args) async {
    final changed = await Navigator.pushNamed(context, route, arguments: args);
    if (changed == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  Future<void> _duplicate(Vehicle v) async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.vehicleForm,
      arguments: VehicleFormArgs(duplicateFromId: v.id),
    );
    if (saved == true && mounted) {
      _didChange = true;
      showSnack(
        context,
        'Copie créée : elle apparaît dans la flotte.',
        kind: SnackKind.success,
      );
    }
  }

  Future<void> _archive(Vehicle v) async {
    final ok = await confirmDialog(
      context,
      title: 'Archiver ce véhicule ?',
      message:
          '${v.brand} ${v.model} sera retiré de la flotte et ne pourra plus être loué. '
          'Son historique (locations, entretiens, incidents) est conservé.',
      confirmLabel: 'Archiver',
      icon: Icons.inventory_2_rounded,
      destructive: false,
    );
    if (ok != true) return;
    try {
      await _repo.archive(v.id!);
      if (!mounted) return;
      showSnack(context, 'Véhicule archivé', kind: SnackKind.success);
      _didChange = true;
      _reload();
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, kind: SnackKind.error);
    }
  }

  Future<void> _restore(Vehicle v) async {
    await _repo.restore(v.id!);
    if (!mounted) return;
    showSnack(
      context,
      'Véhicule remis dans la flotte',
      kind: SnackKind.success,
    );
    _didChange = true;
    _reload();
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
    } on AppException {
      // The vehicle has a history: offer to archive it instead.
      if (!mounted) return;
      final archive = await confirmDialog(
        context,
        title: 'Suppression impossible',
        message:
            'Ce véhicule a des locations ou des incidents enregistrés. '
            'Voulez-vous plutôt l\'archiver ? Il sera retiré de la flotte en gardant son historique.',
        confirmLabel: 'Archiver',
        icon: Icons.inventory_2_rounded,
        destructive: false,
      );
      if (archive == true && mounted) await _archive(vehicle);
    }
  }

  Future<void> _editDocument(
    Vehicle v,
    DocumentType type,
    VehicleDocument? current,
  ) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DocumentEditSheet(
        vehicleId: v.id!,
        type: type,
        current: current,
        repo: _docRepo,
      ),
    );
    if (changed == true && mounted) {
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
                onRetry: _reload,
              ),
            );
          }
          final data = snap.data!;
          final v = data.vehicle!;
          final avail = data.availability;
          final rentable = avail == VehicleAvailability.disponible;
          final blocking = DocumentType.values
              .where(
                (t) =>
                    t.blocksRental &&
                    BusinessRules.documentStatus(
                          data.documents[t]?.expiresOn,
                        ) ==
                        DocumentStatus.expired,
              )
              .toList();

          return Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 330,
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
                        boxShadow: context.softShadow,
                      ),
                      child: DetailMenu(
                        items: [
                          DetailMenuItem(
                            'Modifier',
                            Icons.edit_rounded,
                            () => _push(
                              Routes.vehicleForm,
                              VehicleFormArgs(vehicleId: v.id),
                            ),
                          ),
                          DetailMenuItem(
                            'Dupliquer',
                            Icons.copy_rounded,
                            () => _duplicate(v),
                          ),
                          DetailMenuItem(
                            'Disponibilités',
                            Icons.calendar_month_rounded,
                            () => _push(Routes.availability, IdArgs(v.id!)),
                          ),
                          DetailMenuItem(
                            'Fiche PDF',
                            Icons.picture_as_pdf_rounded,
                            () => exportVehicleSheet(context, v.id!),
                          ),
                          v.archived
                              ? DetailMenuItem(
                                  'Remettre dans la flotte',
                                  Icons.unarchive_rounded,
                                  () => _restore(v),
                                )
                              : DetailMenuItem(
                                  'Archiver',
                                  Icons.inventory_2_rounded,
                                  () => _archive(v),
                                ),
                          DetailMenuItem(
                            'Supprimer',
                            Icons.delete_outline_rounded,
                            () => _delete(v),
                            destructive: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        _Gallery(
                          vehicle: v,
                          index: _photoIndex,
                          onChanged: (i) => setState(() => _photoIndex = i),
                        ),
                        // Rounded top of the content sheet, drawn over the
                        // photo so it scrolls with it.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: -1,
                          child: Container(
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: context.theme.scaffoldBackgroundColor,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppRadius.xl),
                              ),
                            ),
                            child: Container(
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: context.palette.border,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ColoredBox(
                    color: context.theme.scaffoldBackgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 24),
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
                                    GradientText(
                                      v.brand.toUpperCase(),
                                      style: context.text.labelMedium?.copyWith(
                                        letterSpacing: 1.6,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      v.model,
                                      style: context.text.headlineMedium,
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: vehicleAvailabilityChip(avail),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: context.palette.border,
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  v.plate,
                                  style: context.text.labelMedium?.copyWith(
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.event_outlined,
                                size: 16,
                                color: context.palette.muted,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Ajouté le ${formatShortDate(v.createdAt)}',
                                  style: context.text.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (v.archived) ...[
                            const SizedBox(height: 14),
                            InfoBanner(
                              icon: Icons.inventory_2_rounded,
                              color: AppColors.muted,
                              text:
                                  'Véhicule archivé${v.archivedAt == null ? '' : ' le ${formatDate(v.archivedAt!)}'} : '
                                  'retiré de la flotte, historique conservé.',
                              action: TextButton(
                                onPressed: () => _restore(v),
                                child: const Text('Restaurer'),
                              ),
                            ),
                          ] else if (blocking.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            InfoBanner(
                              icon: Icons.gavel_rounded,
                              color: AppColors.danger,
                              text:
                                  'Location bloquée : ${blocking.map((t) => '${t.label.toLowerCase()} expirée le ${formatDate(data.documents[t]!.expiresOn)}').join(' et ')}. '
                                  'Renouvelez le document pour louer ce véhicule.',
                            ),
                          ],
                          const SizedBox(height: 18),
                          _SpecsCard(
                            vehicle: v,
                            onComplete: () => _push(
                              Routes.vehicleForm,
                              VehicleFormArgs(vehicleId: v.id),
                            ),
                          ),
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
                                value: formatMoneyShort(v.pricePerDay),
                              ),
                              InfoTile(
                                icon: Icons.receipt_long_rounded,
                                label: 'Locations',
                                value: '${data.stats.rentals}',
                                color: AppColors.info,
                              ),
                              InfoTile(
                                icon: Icons.savings_rounded,
                                label: 'Revenu généré',
                                value: formatMoneyShort(data.stats.revenue),
                                color: AppColors.success,
                              ),
                              InfoTile(
                                icon: Icons.toggle_on_rounded,
                                label: 'Mise en location',
                                value: v.available ? 'Activée' : 'Désactivée',
                                color: v.available
                                    ? AppColors.teal
                                    : AppColors.danger,
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          SectionCard(
                            title: 'Documents administratifs',
                            icon: Icons.folder_shared_rounded,
                            iconColor: AppColors.violet,
                            children: [
                              for (final t in DocumentType.values)
                                _DocumentRow(
                                  type: t,
                                  document: data.documents[t],
                                  onTap: () =>
                                      _editDocument(v, t, data.documents[t]),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                'Touchez un document pour mettre à jour son échéance.',
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
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
                                  Routes.maintenanceHistory,
                                  IdArgs(v.id!),
                                ),
                              ),
                              _ActionRow(
                                icon: Icons.event_repeat_rounded,
                                color: AppColors.warning,
                                label: 'Planifier un entretien',
                                onTap: () => _push(
                                  Routes.maintenanceForm,
                                  MaintenanceFormArgs(vehicleId: v.id),
                                ),
                              ),
                              _ActionRow(
                                icon: Icons.report_gmailerrorred_rounded,
                                color: AppColors.danger,
                                label: 'Déclarer un incident',
                                trailing: data.stats.incidents > 0
                                    ? '${data.stats.incidents}'
                                    : null,
                                onTap: () => _push(
                                  Routes.incidentForm,
                                  IncidentFormArgs(vehicleId: v.id),
                                ),
                              ),
                            ],
                          ),
                          if (data.rentals.isNotEmpty) ...[
                            const SectionHeader(title: 'Dernières locations'),
                            for (final r in data.rentals)
                              RentalTile(
                                view: r,
                                onTap: () => _push(
                                  Routes.rentalDetail,
                                  IdArgs(r.rental.id!),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: BottomActionBar(
              child: v.archived
                  ? PrimaryButton(
                      label: 'Remettre dans la flotte',
                      icon: Icons.unarchive_rounded,
                      onPressed: () => _restore(v),
                    )
                  : Row(
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('À partir de', style: context.text.bodySmall),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                GradientText(
                                  v.pricePerDay.toStringAsFixed(0),
                                  style: context.text.headlineMedium?.copyWith(
                                    letterSpacing: -1,
                                  ),
                                ),
                                Text(' DT/j', style: context.text.bodySmall),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: PrimaryButton(
                            label: rentable ? 'Louer maintenant' : avail.label,
                            icon: rentable
                                ? Icons.key_rounded
                                : Icons.block_rounded,
                            onPressed: rentable
                                ? () => _push(
                                    Routes.rentalForm,
                                    RentalFormArgs(vehicleId: v.id),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Technical sheet
// ─────────────────────────────────────────────────────────────────────────────
class _SpecsCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onComplete;
  const _SpecsCard({required this.vehicle, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final specs = <(IconData, String, String?)>[
      (Icons.category_rounded, 'Catégorie', v.category?.label),
      (
        v.fuel == null ? Icons.local_gas_station_rounded : fuelIcon(v.fuel!),
        'Carburant',
        v.fuel?.label,
      ),
      (Icons.settings_rounded, 'Boîte', v.gearbox?.label),
      (Icons.event_seat_rounded, 'Places', v.seats?.toString()),
      (Icons.event_rounded, 'Année', v.year?.toString()),
      (Icons.palette_rounded, 'Couleur', v.color),
      (
        Icons.speed_rounded,
        'Kilométrage',
        v.mileage == null ? null : '${_thousands(v.mileage!)} km',
      ),
    ];
    final missing = specs.where((s) => s.$3 == null).length;

    return SectionCard(
      title: 'Caractéristiques',
      icon: Icons.tune_rounded,
      iconColor: AppColors.info,
      trailing: missing == 0
          ? null
          : TextButton(onPressed: onComplete, child: const Text('Compléter')),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.55,
          children: [
            for (final s in specs)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: context.palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    IconBadge(
                      icon: s.$1,
                      color: AppColors.info,
                      size: 30,
                      iconSize: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.$2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodySmall?.copyWith(
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            s.$3 ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall?.copyWith(
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  static String _thousands(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ' ',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Documents
// ─────────────────────────────────────────────────────────────────────────────
class _DocumentRow extends StatelessWidget {
  final DocumentType type;
  final VehicleDocument? document;
  final VoidCallback onTap;
  const _DocumentRow({
    required this.type,
    required this.document,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = BusinessRules.documentStatus(document?.expiresOn);
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            IconBadge(
              icon: documentTypeIcon(type),
              color: documentStatusColor(status),
              size: 40,
              iconSize: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(type.label, style: context.text.titleSmall),
                      if (type.blocksRental)
                        Text(
                          ' *',
                          style: context.text.titleSmall?.copyWith(
                            color: AppColors.violet,
                          ),
                        ),
                    ],
                  ),
                  Text(
                    document == null
                        ? 'Aucune échéance enregistrée'
                        : 'Échéance le ${formatDate(document!.expiresOn)}'
                              '${document!.number == null ? '' : ' · ${document!.number}'}',
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            documentStatusChip(document?.expiresOn),
          ],
        ),
      ),
    );
  }
}

class _DocumentEditSheet extends StatefulWidget {
  final int vehicleId;
  final DocumentType type;
  final VehicleDocument? current;
  final VehicleDocumentRepository repo;
  const _DocumentEditSheet({
    required this.vehicleId,
    required this.type,
    required this.current,
    required this.repo,
  });

  @override
  State<_DocumentEditSheet> createState() => _DocumentEditSheetState();
}

class _DocumentEditSheetState extends State<_DocumentEditSheet> {
  late DateTime? _date = widget.current?.expiresOn;
  late final _number = TextEditingController(
    text: widget.current?.number ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 15),
      helpText: "Date d'expiration · ${widget.type.label}",
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_date == null) return;
    setState(() => _saving = true);
    final n = _number.text.trim();
    await widget.repo.save(
      VehicleDocument(
        vehicleId: widget.vehicleId,
        type: widget.type,
        number: n.isEmpty ? null : n,
        expiresOn: _date!,
        updatedAt: DateTime.now(),
      ),
    );
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _remove() async {
    await widget.repo.remove(widget.vehicleId, widget.type);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconBadge(
                icon: documentTypeIcon(widget.type),
                color: AppColors.violet,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.type.label, style: context.text.titleMedium),
                    Text(
                      widget.type.blocksRental
                          ? 'Obligatoire pour louer le véhicule'
                          : 'Alerte avant échéance',
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          InkWell(
            onTap: _pick,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: "Date d'expiration",
                prefixIcon: Icon(Icons.calendar_today_rounded),
              ),
              child: Text(
                _date == null ? 'Choisir une date' : formatShortDate(_date!),
              ),
            ),
          ),
          if (_date != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: documentStatusChip(_date),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _number,
            decoration: const InputDecoration(
              labelText: 'Numéro (police, PV, quittance…)',
              prefixIcon: Icon(Icons.numbers_rounded),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              if (widget.current != null) ...[
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      minimumSize: const Size(0, 54),
                    ),
                    onPressed: _saving ? null : _remove,
                    child: const Text('Supprimer'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: 'Enregistrer',
                  icon: Icons.check_rounded,
                  loading: _saving,
                  onPressed: _date == null ? null : _save,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Gallery & action rows
// ─────────────────────────────────────────────────────────────────────────────
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
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: photos.length,
          onPageChanged: onChanged,
          itemBuilder: (context, i) => GestureDetector(
            onTap: () => Navigator.pushNamed(
              context,
              Routes.photoViewer,
              arguments: PhotoViewerArgs(fileNames: photos, initialIndex: i),
            ),
            child: i == 0
                ? Hero(
                    tag: 'vehicle-${vehicle.id}',
                    child: CarImage(fileName: photos[i], seed: vehicle.id ?? 0),
                  )
                : CarImage(fileName: photos[i], seed: vehicle.id ?? 0),
          ),
        ),
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
            bottom: 40,
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
      ],
    );
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
      child: Row(
        children: [
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
        ],
      ),
    ),
  );
}

class _VehicleDetailData {
  final Vehicle? vehicle;
  final VehicleAvailability availability;
  final VehicleStats stats;
  final List<RentalView> rentals;
  final Map<DocumentType, VehicleDocument> documents;
  _VehicleDetailData({
    required this.vehicle,
    required this.availability,
    required this.stats,
    required this.rentals,
    required this.documents,
  });
}
