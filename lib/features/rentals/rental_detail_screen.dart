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
import '../../repositories/maintenance_repository.dart';
import '../../repositories/rental_repository.dart';
import '../../repositories/vehicle_document_repository.dart';
import '../../repositories/vehicle_repository.dart';
import '../../core/services/contract_pdf.dart';
import 'widgets/booking_calendar.dart';
import 'widgets/rental_tile.dart';

class RentalDetailScreen extends StatefulWidget {
  final int rentalId;
  const RentalDetailScreen({super.key, required this.rentalId});

  @override
  State<RentalDetailScreen> createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen> {
  final _repo = RentalRepository();
  final _vehicleRepo = VehicleRepository();
  late Future<_Data> _future = _load();
  bool _didChange = false;

  Future<_Data> _load() async {
    final view = await _repo.getViewById(widget.rentalId);
    final vehicle =
        view == null ? null : await _vehicleRepo.getById(view.rental.vehicleId);
    return _Data(view, vehicle);
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _push(String route, Object? args) async {
    final changed = await Navigator.pushNamed(context, route, arguments: args);
    if (changed == true && mounted) {
      _didChange = true;
      _reload();
    }
  }

  Future<void> _delete(Rental r) async {
    final ok = await confirmDialog(
      context,
      title: 'Supprimer ce contrat ?',
      message: 'Le contrat #${r.id} sera définitivement supprimé.',
      confirmLabel: 'Supprimer',
    );
    if (ok != true || !mounted) return;
    await _repo.delete(r.id!);
    if (!mounted) return;
    showSnack(context, 'Location supprimée');
    Navigator.pop(context, true);
  }

  /// Hands the keys over — refused while the vehicle is in the workshop.
  Future<void> _start(Rental r) async {
    if (await MaintenanceRepository().hasActiveMaintenance(r.vehicleId)) {
      if (mounted) {
        showSnack(context,
            'Impossible : ce véhicule est en entretien. Terminez l\'entretien ou changez de véhicule.',
            kind: SnackKind.error);
      }
      return;
    }
    // Insurance / roadworthiness test must be valid for the whole rental.
    final docIssue =
        await VehicleDocumentRepository().blockingIssue(r.vehicleId, r.endDate);
    if (docIssue != null) {
      if (mounted) showSnack(context, docIssue, kind: SnackKind.error);
      return;
    }
    if (!mounted) return;
    await _changeStatus(r, RentalStatus.enCours, 'Démarrer la location ?');
  }

  /// Vehicle return with automatic late-fee billing.
  Future<void> _return(Rental r) async {
    final lateDays = BusinessRules.lateDays(r.endDate);
    if (lateDays == 0) {
      final early = DateUtils.dateOnly(DateTime.now())
          .isBefore(DateUtils.dateOnly(r.endDate));
      final ok = await confirmDialog(
        context,
        title: 'Retour du véhicule',
        message: early
            ? 'Retour anticipé : le montant du contrat (${formatMoney(r.totalPrice)}) reste inchangé.'
            : 'Le contrat sera clôturé pour ${formatMoney(r.totalPrice)}.',
        confirmLabel: 'Clôturer',
        icon: Icons.assignment_turned_in_rounded,
        destructive: false,
      );
      if (ok != true) return;
    } else {
      final ok = await _confirmLateReturn(r, lateDays);
      if (ok != true) return;
    }
    await _repo.completeReturn(r);
    if (!mounted) return;
    showSnack(context, 'Location terminée et enregistrée', kind: SnackKind.success);
    _didChange = true;
    _reload();
  }

  Future<bool?> _confirmLateReturn(Rental r, int lateDays) {
    final rate = BusinessRules.dailyRate(r);
    final fee = BusinessRules.lateFee(r);
    return showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const IconBadge(
            icon: Icons.schedule_rounded, color: AppColors.danger, size: 56),
        title: const Text('Retour en retard', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Retour prévu le ${formatShortDate(r.endDate)} : $lateDays jour(s) de retard. '
              'Les jours de retard sont facturés au tarif journalier majoré de '
              '${((BusinessRules.lateFeeMultiplier - 1) * 100).round()} %.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            LabeledRow(label: 'Montant du contrat', value: formatMoney(r.totalPrice)),
            LabeledRow(
                label: '$lateDays j × ${formatMoneyShort(rate)} × ${BusinessRules.lateFeeMultiplier}',
                value: '+ ${formatMoney(fee)}'),
            const Divider(height: 16),
            LabeledRow(
                label: 'Total à facturer',
                value: formatMoney(r.totalPrice + fee),
                emphasize: true),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                onPressed: () => Navigator.pop(dialogCtx, true),
                child: const Text('Facturer'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  /// Extends the contract at the same daily rate.
  Future<void> _extend(Rental r) async {
    final first = r.endDate.add(const Duration(days: 1));
    final booked =
        await _repo.bookedDays(r.vehicleId, excludeId: r.id);
    if (!mounted) return;
    // Last day we can extend to: the day before the next booking, if any.
    var limit = first;
    while (!booked.contains(toIsoDate(limit))) {
      limit = limit.add(const Duration(days: 1));
      if (limit.difference(first).inDays > 365) break;
    }
    final lastFree = limit.subtract(const Duration(days: 1));
    final canExtend = !lastFree.isBefore(first);
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Nouvelle date de retour', style: ctx.text.titleMedium),
            const SizedBox(height: 6),
            Text(
              !canExtend
                  ? 'Aucun jour libre après le ${formatShortDate(r.endDate)} : le véhicule est réservé.'
                  : limit.difference(first).inDays > 365
                      ? 'Prolongation possible sans limite.'
                      : 'Prolongation possible du ${formatShortDate(first)} au ${formatShortDate(lastFree)}.',
              style: ctx.text.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            BookingCalendar(
              booked: booked,
              firstDay: first,
              lockedStart: r.endDate,
              start: r.endDate,
              onChanged: (_, end) => Navigator.pop(ctx, end),
            ),
          ]),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final newTotal = BusinessRules.extendedTotal(r, picked);
    final ok = await confirmDialog(
      context,
      title: 'Prolonger la location ?',
      message:
          'Nouveau retour le ${formatShortDate(picked)}.\nNouveau total : ${formatMoney(newTotal)} '
          '(+ ${formatMoney(newTotal - r.totalPrice)}).',
      confirmLabel: 'Prolonger',
      icon: Icons.update_rounded,
      destructive: false,
    );
    if (ok != true) return;
    try {
      await _repo.extend(r, picked);
      if (!mounted) return;
      showSnack(context, 'Location prolongée jusqu\'au ${formatShortDate(picked)}',
          kind: SnackKind.success);
      _didChange = true;
      _reload();
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message, kind: SnackKind.error);
    }
  }

  Future<void> _changeStatus(Rental r, RentalStatus to, String title) async {
    final ok = await confirmDialog(
      context,
      title: title,
      message: 'Le contrat passera au statut « ${to.label} ».',
      icon: rentalStatusIcon(to),
      destructive: to == RentalStatus.annulee,
    );
    if (ok != true || !mounted) return;
    await _repo.changeStatus(r.id!, to);
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
          if (snap.hasError || snap.data?.view == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Contrat de location')),
              body: ErrorView(
                  error: snap.error ?? 'Location introuvable',
                  onRetry: _reload),
            );
          }
          final view = snap.data!.view!;
          final vehicle = snap.data!.vehicle;
          final r = view.rental;
          final editable = r.status == RentalStatus.reservee ||
              r.status == RentalStatus.enCours;
          final overdue = isRentalOverdue(r);
          final (vName, vPlate) = splitVehicleLabel(view.vehicleLabel);

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context, _didChange),
              ),
              title: Text('Contrat #${r.id}'),
              actions: [
                DetailMenu(items: [
                  if (editable)
                    DetailMenuItem('Prolonger', Icons.update_rounded,
                        () => _extend(r)),
                  if (editable)
                    DetailMenuItem(
                        'Modifier',
                        Icons.edit_rounded,
                        () => _push(
                            Routes.rentalForm,
                            RentalFormArgs(
                                rentalId: r.id,
                                vehicleId: r.vehicleId,
                                clientId: r.clientId))),
                  DetailMenuItem('Contrat PDF', Icons.picture_as_pdf_rounded,
                      () => shareContractPdf(view)),
                  DetailMenuItem(
                      'Déclarer un incident',
                      Icons.report_gmailerrorred_rounded,
                      () => _push(
                          Routes.incidentForm,
                          IncidentFormArgs(
                              vehicleId: r.vehicleId, rentalId: r.id))),
                  DetailMenuItem('Supprimer', Icons.delete_outline_rounded,
                      () => _delete(r),
                      destructive: true),
                ]),
                const SizedBox(width: 8),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                _SummaryCard(rental: r, overdue: overdue),
                const SizedBox(height: 14),
                if (overdue) ...[
                  InfoBanner(
                    icon: Icons.schedule_rounded,
                    color: AppColors.danger,
                    text:
                        'Retour attendu le ${formatDate(r.endDate)} : ${BusinessRules.lateDays(r.endDate)} jour(s) de retard. '
                        'Frais estimés à ce jour : ${formatMoney(BusinessRules.lateFee(r))} '
                        '(tarif journalier + ${((BusinessRules.lateFeeMultiplier - 1) * 100).round()} %).',
                  ),
                  const SizedBox(height: 14),
                ],
                _Timeline(status: r.status),
                const SizedBox(height: 14),
                AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  onTap: () => _push(Routes.clientDetail, IdArgs(r.clientId)),
                  child: Row(children: [
                    AvatarCircle(
                      initials: view.clientName
                          .split(' ')
                          .where((p) => p.isNotEmpty)
                          .take(2)
                          .map((p) => p[0].toUpperCase())
                          .join(),
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Locataire', style: context.text.bodySmall),
                          Text(view.clientName,
                              style: context.text.titleSmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: context.palette.muted),
                  ]),
                ),
                AppCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(12),
                  onTap: () =>
                      _push(Routes.vehicleDetail, IdArgs(r.vehicleId)),
                  child: Row(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: CarImage(
                        fileName: vehicle?.photos.isNotEmpty == true
                            ? vehicle!.photos.first
                            : null,
                        seed: r.vehicleId,
                        width: 64,
                        height: 48,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vName, style: context.text.titleSmall),
                          Text(vPlate, style: context.text.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: context.palette.muted),
                  ]),
                ),
                SectionCard(
                  title: 'Détails du contrat',
                  icon: Icons.description_rounded,
                  children: [
                    LabeledRow(
                        icon: Icons.timelapse_rounded,
                        label: 'Durée',
                        value: '${r.days} jour(s)'),
                    LabeledRow(
                        icon: Icons.sell_outlined,
                        label: 'Tarif journalier',
                        value: formatMoney(r.totalPrice / r.days)),
                    LabeledRow(
                        icon: Icons.person_pin_outlined,
                        label: 'Enregistré par',
                        value: view.userName ?? 'Système'),
                    LabeledRow(
                        icon: Icons.event_note_rounded,
                        label: 'Créé le',
                        value: formatDate(r.createdAt)),
                    const Divider(height: 20),
                    LabeledRow(
                        label: 'Montant total',
                        value: formatMoney(r.totalPrice),
                        emphasize: true),
                  ],
                ),
              ],
            ),
            bottomNavigationBar: _actions(r),
          );
        },
      ),
    );
  }

  Widget? _actions(Rental r) {
    switch (r.status) {
      case RentalStatus.reservee:
        return BottomActionBar(
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(0, 54)),
                onPressed: () => _changeStatus(
                    r, RentalStatus.annulee, 'Annuler la réservation ?'),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: 'Remettre les clés',
                icon: Icons.key_rounded,
                onPressed: () => _start(r),
              ),
            ),
          ]),
        );
      case RentalStatus.enCours:
        return BottomActionBar(
          child: Row(children: [
            Expanded(
              flex: 2,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 54),
                    padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: () => _extend(r),
                child: const Text('Prolonger', maxLines: 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: PrimaryButton(
                label: 'Restituer',
                icon: Icons.assignment_turned_in_rounded,
                color: isRentalOverdue(r) ? AppColors.danger : AppColors.success,
                onPressed: () => _return(r),
              ),
            ),
          ]),
        );
      case RentalStatus.terminee:
      case RentalStatus.annulee:
        return null;
    }
  }
}

class _SummaryCard extends StatelessWidget {
  final Rental rental;
  final bool overdue;
  const _SummaryCard({required this.rental, required this.overdue});

  @override
  Widget build(BuildContext context) {
    final color = overdue ? AppColors.danger : rentalStatusColor(rental.status);
    return AuroraBackground(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(AppRadius.lg + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            StatusChip(
              label: overdue ? 'En retard' : rental.status.label,
              color: color,
              solid: true,
              icon: overdue ? Icons.schedule_rounded : rentalStatusIcon(rental.status),
            ),
            const Spacer(),
            Text('${rental.days} jour(s)',
                style: context.text.labelMedium
                    ?.copyWith(color: Colors.white.withValues(alpha: 0.7))),
          ]),
          const SizedBox(height: 16),
          Text('Montant total',
              style: context.text.bodySmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.6))),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatMoney(rental.totalPrice),
                style:
                    context.text.headlineMedium?.copyWith(color: Colors.white)),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _DateBlock(
                    label: 'Départ', date: rental.startDate, alignEnd: false)),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_forward_rounded,
                  color: Colors.white, size: 18),
            ),
            Expanded(
                child: _DateBlock(
                    label: 'Retour', date: rental.endDate, alignEnd: true)),
          ]),
        ],
      ),
    );
  }
}

class _DateBlock extends StatelessWidget {
  final String label;
  final DateTime date;
  final bool alignEnd;
  const _DateBlock(
      {required this.label, required this.date, required this.alignEnd});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(label,
              style: context.text.bodySmall
                  ?.copyWith(color: Colors.white.withValues(alpha: 0.6))),
          Text(formatShortDate(date),
              style: context.text.titleSmall?.copyWith(color: Colors.white)),
        ],
      );
}

class _Timeline extends StatelessWidget {
  final RentalStatus status;
  const _Timeline({required this.status});

  @override
  Widget build(BuildContext context) {
    final cancelled = status == RentalStatus.annulee;
    final steps = [
      RentalStatus.reservee,
      RentalStatus.enCours,
      cancelled ? RentalStatus.annulee : RentalStatus.terminee,
    ];
    final current = switch (status) {
      RentalStatus.reservee => 0,
      RentalStatus.enCours => 1,
      _ => 2,
    };
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(children: [
        for (var i = 0; i < steps.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 3,
                margin: const EdgeInsets.only(bottom: 22),
                decoration: BoxDecoration(
                  color: i <= current
                      ? rentalStatusColor(steps[i])
                      : context.palette.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i <= current
                    ? rentalStatusColor(steps[i])
                    : context.palette.surfaceAlt,
              ),
              child: Icon(
                i < current ? Icons.check_rounded : rentalStatusIcon(steps[i]),
                size: 18,
                color: i <= current ? Colors.white : context.palette.muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(steps[i].label,
                style: context.text.labelSmall?.copyWith(
                    color: i <= current ? null : context.palette.muted)),
          ]),
        ],
      ]),
    );
  }
}

class _Data {
  final RentalView? view;
  final Vehicle? vehicle;
  const _Data(this.view, this.vehicle);
}
