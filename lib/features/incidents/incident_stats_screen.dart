import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/enums.dart';
import '../../models/incident_stats.dart';
import '../../repositories/incident_repository.dart';
import 'widgets/incident_sheets.dart';
import 'widgets/incident_ui.dart';

/// "Suivi des incidents": follow-up dashboard for the agent — workload,
/// resolution rate and time, breakdowns, most affected vehicles and the
/// latest status changes.
class IncidentStatsScreen extends StatefulWidget {
  const IncidentStatsScreen({super.key});

  @override
  State<IncidentStatsScreen> createState() => _IncidentStatsScreenState();
}

class _IncidentStatsScreenState extends State<IncidentStatsScreen> {
  final _repo = IncidentRepository();
  late Future<IncidentStats> _future = _repo.getStats();

  Future<void> _reload() async {
    final f = _repo.getStats();
    setState(() => _future = f);
    await f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Suivi des incidents')),
      body: FutureBuilder<IncidentStats>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return ErrorView(error: snap.error!, onRetry: _reload);
          }
          final s = snap.data!;
          var i = 0;
          Widget animated(Widget child) => EntranceAnimation(
            delay: Duration(milliseconds: 70 * i++),
            child: child,
          );
          return RefreshIndicator(
            onRefresh: _reload,
            child: ResponsiveCenter(
              maxWidth: 850,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                children: [
                  animated(_HeroCard(stats: s)),
                  const SizedBox(height: 14),
                  animated(
                    IncidentSection(
                      icon: Icons.donut_large_rounded,
                      iconColor: AppColors.info,
                      title: 'Répartition par statut',
                      child: _StatusBreakdown(stats: s),
                    ),
                  ),
                  animated(
                    IncidentSection(
                      icon: Icons.category_rounded,
                      iconColor: AppColors.violet,
                      title: 'Par type',
                      child: _TypeBreakdown(stats: s),
                    ),
                  ),
                  animated(
                    IncidentSection(
                      icon: Icons.directions_car_rounded,
                      iconColor: AppColors.teal,
                      title: 'Véhicules les plus touchés',
                      child: _TopVehicles(stats: s),
                    ),
                  ),
                  animated(
                    IncidentSection(
                      icon: Icons.history_rounded,
                      title: 'Activité récente',
                      child: _RecentActivity(stats: s),
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
// Formatting helpers
// ─────────────────────────────────────────────────────────────────────────────

/// "< 1 h", "5 h", "2 j 3 h".
String formatResolution(Duration? d) {
  if (d == null) return '—';
  if (d.inMinutes < 60) return '< 1 h';
  if (d.inHours < 24) return '${d.inHours} h';
  final h = d.inHours % 24;
  return h == 0 ? '${d.inDays} j' : '${d.inDays} j $h h';
}

/// "À l'instant", "Il y a 5 min", "Il y a 3 h", then relative day.
String relativeDateTime(DateTime t, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(t);
  if (diff.inMinutes < 1) return "À l'instant";
  if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
  return relativeDate(t);
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero card: open incidents + key figures
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final IncidentStats stats;
  const _HeroCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    Widget figure(IconData icon, String value, String label) => Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11.5),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Incidents à traiter',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    AnimatedCount(
                      value: stats.open,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      '${stats.byStatus[IncidentStatus.enAttente] ?? 0} en attente · '
                      '${stats.byStatus[IncidentStatus.enCours] ?? 0} en cours',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _ResolutionRing(rate: stats.resolutionRate),
            ],
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 14),
          Row(
            children: [
              figure(
                Icons.summarize_rounded,
                '${stats.total}',
                'Total déclarés',
              ),
              figure(
                Icons.date_range_rounded,
                '${stats.last30Days}',
                '30 derniers jours',
              ),
              figure(
                Icons.timer_rounded,
                formatResolution(stats.averageResolution),
                'Délai moyen de résolution',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolutionRing extends StatelessWidget {
  final double rate;
  const _ResolutionRing({required this.rate});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: rate),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: v,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white24,
              color: AppColors.brand,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(v * 100).round()} %',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'résolus',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Status breakdown: stacked bar + legend
// ─────────────────────────────────────────────────────────────────────────────
class _StatusBreakdown extends StatelessWidget {
  final IncidentStats stats;
  const _StatusBreakdown({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.total;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: total == 0
                ? Container(color: context.palette.surfaceAlt)
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => Row(
                      children: [
                        for (final s in IncidentStatus.values)
                          if ((stats.byStatus[s] ?? 0) > 0)
                            Expanded(
                              flex: math.max(
                                1,
                                ((stats.byStatus[s]! / total) * 1000 * t)
                                    .round(),
                              ),
                              child: Container(color: s.color),
                            ),
                        if (t < 1)
                          Expanded(
                            flex: math.max(1, (1000 * (1 - t)).round()),
                            child: Container(
                              color: context.palette.surfaceAlt,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 14),
        for (final s in IncidentStatus.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: s.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(s.icon, size: 18, color: s.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.pluralLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                AnimatedCount(
                  value: stats.byStatus[s] ?? 0,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(
                  width: 54,
                  child: Text(
                    total == 0
                        ? '0 %'
                        : '${((stats.byStatus[s] ?? 0) * 100 / total).round()} %',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: context.palette.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Type breakdown: two tiles
// ─────────────────────────────────────────────────────────────────────────────
class _TypeBreakdown extends StatelessWidget {
  final IncidentStats stats;
  const _TypeBreakdown({required this.stats});

  @override
  Widget build(BuildContext context) {
    final total = stats.total;
    return Row(
      children: [
        for (final t in IncidentType.values) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.color.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IncidentTypeBadge(type: t, size: 36),
                      const Spacer(),
                      AnimatedCount(
                        value: stats.byType[t] ?? 0,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: t.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${t.label}s',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 0,
                        end: total == 0 ? 0 : (stats.byType[t] ?? 0) / total,
                      ),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => LinearProgressIndicator(
                        value: v,
                        minHeight: 6,
                        color: t.color,
                        backgroundColor: t.color.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (t != IncidentType.values.last) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Most affected vehicles
// ─────────────────────────────────────────────────────────────────────────────
class _TopVehicles extends StatelessWidget {
  final IncidentStats stats;
  const _TopVehicles({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.topVehicles.isEmpty) {
      return Text(
        'Aucun incident enregistré.',
        style: TextStyle(color: context.palette.muted),
      );
    }
    final max = stats.topVehicles.first.count;
    return Column(
      children: [
        for (final (i, v) in stats.topVehicles.indexed)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pushNamed(
              context,
              Routes.vehicleDetail,
              arguments: IdArgs(v.vehicleId),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: i == 0
                        ? AppColors.brand
                        : AppColors.brand.withValues(alpha: 0.12),
                    child: Text(
                      '${i + 1}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: i == 0 ? Colors.white : AppColors.brand,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.vehicleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: v.count / max),
                            duration: const Duration(milliseconds: 800),
                            curve: Curves.easeOutCubic,
                            builder: (context, x, _) => LinearProgressIndicator(
                              value: x,
                              minHeight: 6,
                              color: AppColors.brand,
                              backgroundColor: AppColors.brand.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${v.count}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recent activity feed
// ─────────────────────────────────────────────────────────────────────────────
class _RecentActivity extends StatelessWidget {
  final IncidentStats stats;
  const _RecentActivity({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.recentActivity.isEmpty) {
      return Text(
        'Aucune activité pour le moment.',
        style: TextStyle(color: context.palette.muted),
      );
    }
    return Column(
      children: [
        for (final a in stats.recentActivity)
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.pushNamed(
              context,
              Routes.incidentDetail,
              arguments: IdArgs(a.entry.incidentId),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: a.entry.toStatus.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      a.entry.isDeclaration
                          ? Icons.add_alert_rounded
                          : a.entry.toStatus.icon,
                      size: 18,
                      color: a.entry.toStatus.color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${a.type.label} #${a.entry.incidentId}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: a.type.color,
                                ),
                              ),
                              TextSpan(
                                text: a.entry.isDeclaration
                                    ? (a.type == IncidentType.panne
                                          ? ' déclarée'
                                          : ' déclaré')
                                    : ' → ${a.entry.toStatus.label}',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${a.vehicleLabel}\n'
                          '${a.entry.userName ?? 'Utilisateur supprimé'} · ${relativeDateTime(a.entry.changedAt)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
