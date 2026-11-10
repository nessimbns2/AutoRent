import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/rental_stats.dart';
import '../../repositories/rental_repository.dart';
import '../incidents/incident_permissions.dart';

/// Admin-only analytics of the rentals module: revenue, contract breakdown,
/// monthly trend and the best vehicles, clients and agents.
class RentalStatsScreen extends StatefulWidget {
  const RentalStatsScreen({super.key});

  @override
  State<RentalStatsScreen> createState() => _RentalStatsScreenState();
}

class _RentalStatsScreenState extends State<RentalStatsScreen> {
  final _repo = RentalRepository();
  late Future<RentalStats> _future = _repo.getStats();

  Future<void> _reload() async {
    final f = _repo.getStats();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    // Reached from an admin-only button, but guard the screen itself too.
    if (!IncidentPermissions.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analyse des locations')),
        body: const EmptyState(
          icon: Icons.lock_outline_rounded,
          title: 'Accès réservé',
          message: "Cette page est réservée à l'administrateur.",
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Analyse des locations')),
      body: FutureBuilder<RentalStats>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorView(error: snap.error!, onRetry: _reload);
          }
          final s = snap.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ResponsiveCenter(
              maxWidth: 850,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  _Hero(stats: s),
                  const SizedBox(height: 14),
                  _Kpis(stats: s),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Répartition par statut',
                    icon: Icons.donut_large_rounded,
                    iconColor: AppColors.info,
                    children: [_StatusBreakdown(stats: s)],
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: "Chiffre d'affaires (6 mois)",
                    icon: Icons.bar_chart_rounded,
                    iconColor: AppColors.success,
                    children: [_MonthBars(stats: s)],
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Véhicules les plus rentables',
                    icon: Icons.directions_car_rounded,
                    iconColor: AppColors.teal,
                    children: [_Ranking(items: s.topVehicles)],
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Meilleurs locataires',
                    icon: Icons.badge_rounded,
                    iconColor: AppColors.violet,
                    children: [_Ranking(items: s.topClients)],
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Contrats par agent',
                    icon: Icons.manage_accounts_rounded,
                    iconColor: AppColors.brand,
                    children: [_Ranking(items: s.byAgent)],
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

class _Hero extends StatelessWidget {
  final RentalStats stats;
  const _Hero({required this.stats});

  @override
  Widget build(BuildContext context) {
    Widget figure(String value, String label) => Expanded(
          child: Column(children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ]),
        );
    return AuroraBackground(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      borderRadius: BorderRadius.circular(AppRadius.xl),
      child: Column(children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text("Chiffre d'affaires total",
              style: TextStyle(color: Colors.white70, fontSize: 14)),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(formatMoney(stats.revenue),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(height: 14),
        Container(height: 1, color: Colors.white24),
        const SizedBox(height: 12),
        Row(children: [
          figure('${stats.total}', 'Contrats'),
          figure(formatMoneyShort(stats.averageAmount), 'Panier moyen'),
          figure('${stats.averageDays.toStringAsFixed(1)} j', 'Durée moyenne'),
        ]),
      ]),
    );
  }
}

class _Kpis extends StatelessWidget {
  final RentalStats stats;
  const _Kpis({required this.stats});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      InfoTile(
          icon: Icons.calendar_month_rounded,
          label: 'CA ce mois',
          value: formatMoneyShort(stats.revenueThisMonth),
          color: AppColors.success),
      InfoTile(
          icon: Icons.key_rounded,
          label: 'En cours',
          value: '${stats.count(RentalStatus.enCours)}',
          color: AppColors.info),
      InfoTile(
          icon: Icons.schedule_rounded,
          label: 'En retard',
          value: '${stats.overdue}',
          color: AppColors.danger),
      InfoTile(
          icon: Icons.cancel_outlined,
          label: "Taux d'annulation",
          value: '${(stats.cancellationRate * 100).round()} %',
          color: AppColors.warning),
    ];
    return Column(children: [
      Row(children: [
        Expanded(child: tiles[0]),
        const SizedBox(width: 10),
        Expanded(child: tiles[1]),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: tiles[2]),
        const SizedBox(width: 10),
        Expanded(child: tiles[3]),
      ]),
    ]);
  }
}

class _StatusBreakdown extends StatelessWidget {
  final RentalStats stats;
  const _StatusBreakdown({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.total;
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 14,
          child: total == 0
              ? Container(color: context.palette.surfaceAlt)
              : Row(children: [
                  for (final s in RentalStatus.values)
                    if (stats.count(s) > 0)
                      Expanded(
                          flex: stats.count(s),
                          child: Container(color: rentalStatusColor(s))),
                ]),
        ),
      ),
      const SizedBox(height: 12),
      for (final s in RentalStatus.values)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                    color: rentalStatusColor(s), shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(child: Text(s.label, style: context.text.bodyMedium)),
            Text('${stats.count(s)}', style: context.text.titleSmall),
            SizedBox(
              width: 48,
              child: Text(
                total == 0 ? '0 %' : '${(stats.count(s) * 100 / total).round()} %',
                textAlign: TextAlign.end,
                style: context.text.bodySmall,
              ),
            ),
          ]),
        ),
    ]);
  }
}

class _MonthBars extends StatelessWidget {
  final RentalStats stats;
  const _MonthBars({required this.stats});

  @override
  Widget build(BuildContext context) {
    final max = stats.monthly.fold<double>(0, (m, e) => math.max(m, e.amount));
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final m in stats.monthly)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(m.amount == 0 ? '' : formatMoneyShort(m.amount),
                      style: context.text.labelSmall),
                  const SizedBox(height: 4),
                  Container(
                    height: max == 0 ? 4 : math.max(4, 100 * m.amount / max),
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(monthLabel(m.month), style: context.text.labelSmall),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Ranking extends StatelessWidget {
  final List<RankedItem> items;
  const _Ranking({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text('Pas encore de données.', style: context.text.bodySmall);
    }
    final max = items.first.revenue;
    return Column(children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${i + 1}. ${items[i].label}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall),
              ),
              Text(formatMoneyShort(items[i].revenue),
                  style: context.text.titleSmall),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : items[i].revenue / max,
                minHeight: 6,
                backgroundColor: context.palette.surfaceAlt,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 2),
            Text('${items[i].count} contrat${items[i].count > 1 ? 's' : ''}',
                style: context.text.bodySmall),
          ]),
        ),
    ]);
  }
}
