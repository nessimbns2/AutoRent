import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/services/theme_controller.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../repositories/dashboard_repository.dart';
import '../rentals/widgets/rental_tile.dart';
import '../services/services_tab.dart';

class DashboardTab extends StatefulWidget {
  final void Function(int tab, {ServicesSegment? segment}) onGoToTab;
  const DashboardTab({super.key, required this.onGoToTab});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _repo = DashboardRepository();
  late Future<DashboardData> _future = _load();

  Future<DashboardData> _load() {
    NotificationService.instance.refresh(); // keep the bell badge up to date
    return _repo.load();
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _open(String route, {Object? args}) async {
    final changed = await Navigator.pushNamed(context, route, arguments: args);
    if (changed == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardData>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SafeArea(child: LoadingView());
        }
        if (snap.hasError) {
          return SafeArea(
              child: ErrorView(error: snap.error!, onRetry: _reload));
        }
        final d = snap.data!;
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(
                  data: d,
                  onOpenNotifications: () async {
                    await Navigator.pushNamed(context, Routes.notifications);
                    if (mounted) _reload();
                  }),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (d.overdue > 0) ...[
                      InfoBanner(
                        icon: Icons.schedule_rounded,
                        color: AppColors.danger,
                        text: d.overdue == 1
                            ? '1 location a dépassé sa date de retour.'
                            : '${d.overdue} locations ont dépassé leur date de retour.',
                        action: TextButton(
                          onPressed: () => widget.onGoToTab(2),
                          child: const Text('Voir'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _KpiGrid(data: d, onGoToTab: widget.onGoToTab),
                    const SizedBox(height: 18),
                    _QuickActions(onOpen: _open),
                    const SizedBox(height: 18),
                    _FleetCard(
                        fleet: d.fleet, onTap: () => widget.onGoToTab(1)),
                    const SizedBox(height: 10),
                    SectionHeader(
                      title: "À traiter aujourd'hui",
                      actionLabel: 'Locations',
                      onAction: () => widget.onGoToTab(2),
                    ),
                    if (d.departures.isEmpty && d.returns.isEmpty)
                      const AppCard(
                        child: Row(children: [
                          IconBadge(
                              icon: Icons.beach_access_rounded,
                              color: AppColors.success),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                                'Aucun départ ni retour en attente. Belle journée !'),
                          ),
                        ]),
                      )
                    else ...[
                      for (final v in d.departures)
                        _AgendaTile(
                          label: 'Départ',
                          color: AppColors.warning,
                          icon: Icons.north_east_rounded,
                          title: splitVehicleLabel(v.vehicleLabel).$1,
                          subtitle: '${v.clientName} · ${relativeDay(v.rental.startDate)}',
                          onTap: () => _open(Routes.rentalDetail,
                              args: IdArgs(v.rental.id!)),
                        ),
                      for (final v in d.returns)
                        _AgendaTile(
                          label: isRentalOverdue(v.rental) ? 'En retard' : 'Retour',
                          color: isRentalOverdue(v.rental)
                              ? AppColors.danger
                              : AppColors.info,
                          icon: Icons.south_west_rounded,
                          title: splitVehicleLabel(v.vehicleLabel).$1,
                          subtitle: '${v.clientName} · ${relativeDay(v.rental.endDate)}',
                          onTap: () => _open(Routes.rentalDetail,
                              args: IdArgs(v.rental.id!)),
                        ),
                    ],
                    const SizedBox(height: 10),
                    SectionHeader(
                      title: 'Entretiens à venir',
                      actionLabel: 'Tout voir',
                      onAction: () => widget.onGoToTab(3,
                          segment: ServicesSegment.maintenances),
                    ),
                    if (d.upcomingMaintenances.isEmpty)
                      const AppCard(
                        child: Row(children: [
                          IconBadge(
                              icon: Icons.verified_rounded,
                              color: AppColors.success),
                          SizedBox(width: 12),
                          Expanded(
                              child: Text(
                                  'Aucun entretien prévu dans les 14 prochains jours.')),
                        ]),
                      )
                    else
                      for (final m in d.upcomingMaintenances)
                        _AgendaTile(
                          label: m.maintenance.status.label,
                          color: maintenanceStatusColor(m.maintenance.status),
                          icon: maintenanceTypeIcon(m.maintenance.type),
                          title:
                              '${m.maintenance.type} · ${splitVehicleLabel(m.vehicleLabel).$1}',
                          subtitle: relativeDay(m.maintenance.date),
                          onTap: () => _open(Routes.maintenanceDetail,
                              args: IdArgs(m.maintenance.id!)),
                        ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — greeting + revenue card with a 6-month mini chart
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final DashboardData data;
  final VoidCallback onOpenNotifications;
  const _Header({required this.data, required this.onOpenNotifications});

  @override
  Widget build(BuildContext context) {
    final user = SessionManager.instance.currentUser;
    final hour = DateTime.now().hour;
    final greeting = hour < 18 ? 'Bonjour' : 'Bonsoir';
    final trend = data.revenueTrend;
    final now = DateTime.now();

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 16, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                AvatarCircle(
                  initials: user?.initials ?? 'AR',
                  photoFile: user?.photoFile,
                  size: 46,
                  color: AppColors.brand,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$greeting, ${user?.firstName ?? ''}',
                          style: context.text.titleMedium
                              ?.copyWith(color: Colors.white)),
                      Text(
                        formatLongDay(now).replaceRange(
                            0, 1, formatLongDay(now)[0].toUpperCase()),
                        style: context.text.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.65)),
                      ),
                    ],
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: NotificationService.instance.unread,
                  builder: (context, count, _) => CircleIconButton(
                    icon: count > 0
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_none_rounded,
                    tooltip: 'Notifications',
                    color: Colors.white,
                    background: Colors.white.withValues(alpha: 0.12),
                    badge: count > 0 ? count : null,
                    onPressed: onOpenNotifications,
                  ),
                ),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.instance.mode,
                  builder: (context, mode, _) => CircleIconButton(
                    icon: mode == ThemeMode.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                    tooltip: mode == ThemeMode.dark
                        ? 'Mode clair'
                        : 'Mode sombre',
                    color: Colors.white,
                    background: Colors.white.withValues(alpha: 0.12),
                    onPressed: () => ThemeController.instance
                        .setDark(mode != ThemeMode.dark),
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Chiffre d'affaires · ${monthLabel(now.month)}",
                              style: context.text.bodySmall?.copyWith(
                                  color:
                                      Colors.white.withValues(alpha: 0.65))),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(formatMoneyShort(data.monthRevenue),
                                style: context.text.headlineMedium
                                    ?.copyWith(color: Colors.white)),
                          ),
                          const SizedBox(height: 8),
                          if (trend != null)
                            StatusChip(
                              label:
                                  '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(0)} % vs mois dernier',
                              color: trend >= 0
                                  ? const Color(0xFF4ADE80)
                                  : const Color(0xFFFF8A8A),
                              icon: trend >= 0
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                            )
                          else
                            Text('Locations non annulées',
                                style: context.text.bodySmall?.copyWith(
                                    color:
                                        Colors.white.withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _MiniBars(revenue: data.revenue),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniBars extends StatelessWidget {
  final List<MonthRevenue> revenue;
  const _MiniBars({required this.revenue});

  @override
  Widget build(BuildContext context) {
    final max = revenue.fold<double>(0, (m, r) => r.amount > m ? r.amount : m);
    return SizedBox(
      height: 86,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < revenue.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Tooltip(
                message:
                    '${monthLabel(revenue[i].month)} : ${formatMoneyShort(revenue[i].amount)}',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                          begin: 0,
                          end: max == 0 ? 0.06 : (revenue[i].amount / max)
                              .clamp(0.06, 1.0)),
                      duration: Duration(milliseconds: 500 + i * 80),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, _) => Container(
                        width: 12,
                        height: 62 * v,
                        decoration: BoxDecoration(
                          color: i == revenue.length - 1
                              ? AppColors.brand
                              : Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      monthLabel(revenue[i].month).substring(0, 1).toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KPI grid
// ─────────────────────────────────────────────────────────────────────────────
class _KpiGrid extends StatelessWidget {
  final DashboardData data;
  final void Function(int tab, {ServicesSegment? segment}) onGoToTab;
  const _KpiGrid({required this.data, required this.onGoToTab});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _Kpi(
        icon: Icons.directions_car_rounded,
        color: AppColors.info,
        value: '${data.rentalsByStatus[RentalStatus.enCours] ?? 0}',
        label: 'Locations en cours',
        onTap: () => onGoToTab(2),
      ),
      _Kpi(
        icon: Icons.event_available_rounded,
        color: AppColors.warning,
        value: '${data.rentalsByStatus[RentalStatus.reservee] ?? 0}',
        label: 'Réservations',
        onTap: () => onGoToTab(2),
      ),
      _Kpi(
        icon: Icons.key_rounded,
        color: AppColors.success,
        value: '${data.fleet.available}/${data.fleet.total}',
        label: 'Véhicules libres',
        onTap: () => onGoToTab(1),
      ),
      _Kpi(
        icon: Icons.report_rounded,
        color: AppColors.danger,
        value: '${data.pendingIncidents}',
        label: 'Incidents ouverts',
        onTap: () => onGoToTab(3, segment: ServicesSegment.incidents),
      ),
    ];
    return Column(children: [
      Row(children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 12),
        Expanded(child: cards[1]),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: cards[2]),
        const SizedBox(width: 12),
        Expanded(child: cards[3]),
      ]),
    ]);
  }
}

class _Kpi extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback onTap;
  const _Kpi({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              IconBadge(icon: icon, color: color, size: 38, iconSize: 20),
              const Spacer(),
              Icon(Icons.arrow_outward_rounded,
                  size: 18, color: context.palette.muted),
            ]),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: context.text.headlineSmall),
            ),
            Text(label,
                style: context.text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick actions
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final Future<void> Function(String route, {Object? args}) onOpen;
  const _QuickActions({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.car_rental_rounded, 'Louer', AppColors.brand, Routes.rentalForm),
      (Icons.add_circle_outline_rounded, 'Véhicule', AppColors.info,
          Routes.vehicleForm),
      (Icons.build_rounded, 'Entretien', AppColors.teal,
          Routes.maintenanceForm),
      (Icons.report_gmailerrorred_rounded, 'Incident', AppColors.danger,
          Routes.incidentForm),
    ];
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Row(
        children: [
          for (final a in actions)
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => onOpen(a.$4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(children: [
                    IconBadge(icon: a.$1, color: a.$3, size: 50, filled: true),
                    const SizedBox(height: 8),
                    Text(a.$2, style: context.text.labelMedium),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fleet status card — stacked bar + legend
// ─────────────────────────────────────────────────────────────────────────────
class _FleetCard extends StatelessWidget {
  final FleetStatus fleet;
  final VoidCallback onTap;
  const _FleetCard({required this.fleet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final parts = [
      ('Disponibles', fleet.available, AppColors.success),
      ('Louées', fleet.rented, AppColors.info),
      ('Entretien', fleet.maintenance, AppColors.warning),
      ('Indisponibles', fleet.unavailable, AppColors.danger),
    ];
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text('État de la flotte',
                    style: context.text.titleSmall)),
            Text('${(fleet.occupancy * 100).toStringAsFixed(0)} % louée',
                style: context.text.labelMedium
                    ?.copyWith(color: AppColors.brand)),
          ]),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: fleet.total == 0
                  ? ColoredBox(color: context.palette.surfaceAlt)
                  : Row(children: [
                      for (final p in parts)
                        if (p.$2 > 0)
                          Expanded(
                            flex: p.$2,
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              color: p.$3,
                            ),
                          ),
                    ]),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              for (final p in parts)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: p.$3, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 6),
                  Text('${p.$1} ', style: context.text.bodySmall),
                  Text('${p.$2}', style: context.text.labelMedium),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgendaTile extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _AgendaTile({
    required this.label,
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => AppCard(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        onTap: onTap,
        child: Row(children: [
          IconBadge(icon: icon, color: color, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: context.text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(subtitle,
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          StatusChip(label: label, color: color),
        ]),
      );
}
