import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../repositories/maintenance_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Period filter
// ─────────────────────────────────────────────────────────────────────────────
enum _Period {
  month('Ce mois'),
  threeMonths('3 mois'),
  year('Cette année'),
  all('Tout');

  const _Period(this.label);
  final String label;

  DateTime? get since {
    final now = DateTime.now();
    return switch (this) {
      _Period.month => DateTime(now.year, now.month, 1),
      _Period.threeMonths => DateTime(now.year, now.month - 2, 1),
      _Period.year => DateTime(now.year, 1, 1),
      _Period.all => null,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────
class MaintenanceStatsScreen extends StatefulWidget {
  const MaintenanceStatsScreen({super.key});

  @override
  State<MaintenanceStatsScreen> createState() => _MaintenanceStatsScreenState();
}

class _MaintenanceStatsScreenState extends State<MaintenanceStatsScreen> {
  final _repo = MaintenanceRepository();
  _Period _period = _Period.all;
  late Future<MaintenanceStats> _future = _load();

  Future<MaintenanceStats> _load() => _repo.getStats(since: _period.since);

  void _setPeriod(_Period p) => setState(() {
        _period = p;
        _future = _load();
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Statistiques'),
      ),
      body: Column(
        children: [
          // Period filter
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in _Period.values) ...[
                    _PeriodChip(
                      label: p.label,
                      selected: _period == p,
                      onTap: () => _setPeriod(p),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          // Content
          Expanded(
            child: FutureBuilder<MaintenanceStats>(
              future: _future,
              builder: (context, snap) {
                if (!snap.hasData) return const LoadingView();
                if (snap.hasError) {
                  return ErrorView(
                      error: snap.error!, onRetry: () => setState(() => _future = _load()));
                }
                final stats = snap.data!;
                if (stats.isEmpty) {
                  return const EmptyState(
                    icon: Icons.bar_chart_rounded,
                    title: 'Pas encore de données',
                    message: 'Les statistiques apparaîtront après le premier entretien.',
                  );
                }
                return _StatsBody(stats: stats, onOpenEntretien: _openEntretien);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEntretien(int id) async {
    await Navigator.pushNamed(context, Routes.maintenanceDetail,
        arguments: IdArgs(id));
    if (!mounted) return;
    final next = _load();          // compute Future BEFORE entering setState
    setState(() => _future = next);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Body (scrollable content)
// ─────────────────────────────────────────────────────────────────────────────
class _StatsBody extends StatefulWidget {
  final MaintenanceStats stats;
  final Future<void> Function(int id) onOpenEntretien;
  const _StatsBody({required this.stats, required this.onOpenEntretien});

  @override
  State<_StatsBody> createState() => _StatsBodyState();
}

class _StatsBodyState extends State<_StatsBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(_StatsBody old) {
    super.didUpdateWidget(old);
    if (old.stats != widget.stats) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.stats;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        // ── KPI Grid ──────────────────────────────────────────────────────────
        _SectionLabel('Indicateurs clés'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.12,
          children: [
            _KpiCard(
              icon: Icons.payments_rounded,
              color: AppColors.success,
              label: 'Coût total',
              value: '${s.totalCost.toStringAsFixed(0)} DT',
              subtitle: 'Coûts réels (terminé)',
              explanation:
                  'Somme des coûts réels (cout_reel) de tous les entretiens terminés dans la période sélectionnée.',
              anim: _anim,
            ),
            _KpiCard(
              icon: Icons.build_circle_rounded,
              color: AppColors.info,
              label: 'Interventions',
              value: '${s.totalInterventions}',
              subtitle: 'Total période',
              explanation:
                  'Nombre total d\'entretiens (tous statuts) enregistrés dans la période sélectionnée.',
              anim: _anim,
            ),
            _KpiCard(
              icon: Icons.garage_rounded,
              color: AppColors.warning,
              label: 'Jours immob.',
              value: '${s.totalDays} j',
              subtitle: 'Véhicules en atelier',
              explanation:
                  'Total des jours passés en atelier : calculé entre started_at et ended_at. Minimum 1 jour par entretien.',
              anim: _anim,
            ),
            _KpiCard(
              icon: Icons.trending_down_rounded,
              color: AppColors.danger,
              label: 'Manque à gagner*',
              value: '${s.totalLostRevenue.toStringAsFixed(0)} DT',
              subtitle: '* estimation',
              explanation:
                  'Estimation uniquement : jours immobilisés × tarif journalier du véhicule. Ne tient pas compte des réservations réelles annulées.',
              anim: _anim,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Monthly cost chart ────────────────────────────────────────────────
        _SectionLabel('Coûts mensuels (6 mois)'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: _BarChart(
            data: s.monthlyCosts,
            anim: _anim,
            onBarTap: (key) => _showMonthSheet(key),
          ),
        ),
        const SizedBox(height: 20),

        // ── Cost by type ──────────────────────────────────────────────────────
        _SectionLabel('Coût par type'),
        AppCard(
          padding: const EdgeInsets.all(16),
          child: _TypeBars(
            costByType: s.costByType,
            countByType: s.countByType,
            anim: _anim,
            onTypeTap: (type) => _showTypeSheet(type),
          ),
        ),
        const SizedBox(height: 20),

        // ── Top 3 vehicles ────────────────────────────────────────────────────
        _SectionLabel('Top 3 véhicules par coût'),
        for (int i = 0; i < s.top3Vehicles.length; i++)
          _VehicleRankCard(
            rank: i + 1,
            agg: s.top3Vehicles[i],
            anim: _anim,
            onTap: () => _openVehicleHistory(s.top3Vehicles[i].vehicleId),
          ),
      ],
    );
  }

  void _showMonthSheet(String monthKey) {
    // monthKey = 'yyyy-MM'
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final rows = widget.stats.all
        .where((r) => r.date.year == year && r.date.month == month)
        .toList();
    _showEntretiensSheet(
      context,
      title: '${monthLabel(month)} $year',
      rows: rows,
      onTap: widget.onOpenEntretien,
    );
  }

  void _showTypeSheet(String type) {
    final rows =
        widget.stats.all.where((r) => r.type == type).toList();
    _showEntretiensSheet(
      context,
      title: type,
      rows: rows,
      onTap: widget.onOpenEntretien,
    );
  }

  void _openVehicleHistory(int vehicleId) {
    Navigator.pushNamed(context, Routes.maintenanceHistory,
        arguments: IdArgs(vehicleId));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared bottom sheet helper
// ─────────────────────────────────────────────────────────────────────────────
void _showEntretiensSheet(
  BuildContext context, {
  required String title,
  required List<StatsRow> rows,
  required Future<void> Function(int) onTap,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: ctx.colors.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ctx.palette.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(children: [
              Expanded(
                child: Text(title,
                    style: ctx.text.titleMedium),
              ),
              Text('${rows.length} entretien${rows.length > 1 ? 's' : ''}',
                  style: ctx.text.bodySmall
                      ?.copyWith(color: ctx.palette.muted)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: rows.isEmpty
                ? Center(
                    child: Text('Aucun entretien',
                        style: ctx.text.bodyMedium
                            ?.copyWith(color: ctx.palette.muted)))
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      return Material(
                        type: MaterialType.transparency,
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 4),
                          leading: IconBadge(
                            icon: maintenanceTypeIcon(r.type),
                            color: _typeColor(r.type),
                            size: 40,
                          ),
                          title: Text(r.type,
                              style: ctx.text.titleSmall),
                          subtitle: Text(
                            '${formatShortDate(r.date)} · ${r.vehicleLabel}',
                            style: ctx.text.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: r.costActual != null
                              ? Text(
                                  '${r.costActual!.toStringAsFixed(0)} DT',
                                  style: ctx.text.labelMedium?.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w700),
                                )
                              : null,
                          onTap: () {
                            Navigator.pop(ctx);
                            onTap(r.id);
                          },
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: context.text.titleSmall),
      );
}

// ── Period chip ───────────────────────────────────────────────────────────────
class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected
            ? (context.isDark ? AppColors.brand : AppColors.ink)
            : context.colors.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
            color: selected ? Colors.transparent : context.palette.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              label,
              style: context.text.labelMedium?.copyWith(
                  color: selected ? Colors.white : context.colors.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

// ── KPI card ──────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String subtitle;
  final String explanation;
  final Animation<double> anim;

  const _KpiCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.explanation,
    required this.anim,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: () => _showExplanation(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconBadge(icon: icon, color: color, size: 28, iconSize: 15),
            const Spacer(),
            Icon(Icons.info_outline_rounded,
                size: 14, color: context.palette.muted),
          ]),
          const Spacer(),
          AnimatedBuilder(
            animation: anim,
            builder: (_, _) => Opacity(
              opacity: anim.value,
              child: Text(value,
                  style: context.text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: context.text.bodySmall
                  ?.copyWith(color: context.palette.muted, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(subtitle,
                style: context.text.labelSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ],
      ),
    );
  }

  void _showExplanation(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ctx.colors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          IconBadge(icon: icon, color: color, size: 48, iconSize: 24),
          const SizedBox(height: 12),
          Text(label, style: ctx.text.titleMedium),
          const SizedBox(height: 10),
          Text(explanation,
              textAlign: TextAlign.center,
              style: ctx.text.bodyMedium
                  ?.copyWith(color: ctx.palette.muted, height: 1.5)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Compris'),
            ),
          ),
        ]),
      ),
    );
  }
}

// ── Bar chart (monthly) ───────────────────────────────────────────────────────
class _BarChart extends StatelessWidget {
  final Map<String, double> data;
  final Animation<double> anim;
  final void Function(String key) onBarTap;

  const _BarChart(
      {required this.data, required this.anim, required this.onBarTap});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.values.fold(0.0, max);
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in data.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => onBarTap(entry.key),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Value label
                      if (entry.value > 0)
                        AnimatedBuilder(
                          animation: anim,
                          builder: (_, _) => Opacity(
                            opacity: anim.value,
                            child: Text(
                              entry.value >= 1000
                                  ? '${(entry.value / 1000).toStringAsFixed(1)}k'
                                  : entry.value.toStringAsFixed(0),
                              style: context.text.labelSmall?.copyWith(
                                  fontSize: 9, color: context.palette.muted),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      // Bar
                      AnimatedBuilder(
                        animation: anim,
                        builder: (_, _) {
                          final frac =
                              maxVal > 0 ? entry.value / maxVal : 0.0;
                          return Container(
                            height: 100 * frac * anim.value + (frac > 0 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: entry.value > 0
                                  ? AppColors.brand
                                  : context.palette.border,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(6)),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      // Month label
                      Text(
                        _shortMonthKey(entry.key),
                        style: context.text.labelSmall
                            ?.copyWith(fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _shortMonthKey(String key) {
    final m = int.parse(key.split('-')[1]);
    return monthLabel(m);
  }
}

// ── Type bars ─────────────────────────────────────────────────────────────────
class _TypeBars extends StatelessWidget {
  final Map<String, double> costByType;
  final Map<String, int> countByType;
  final Animation<double> anim;
  final void Function(String) onTypeTap;

  const _TypeBars({
    required this.costByType,
    required this.countByType,
    required this.anim,
    required this.onTypeTap,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = costByType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.isEmpty ? 1.0 : sorted.first.value;

    return Column(
      children: [
        for (final entry in sorted) ...[
          GestureDetector(
            onTap: () => onTypeTap(entry.key),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                // Type icon + name
                IconBadge(
                    icon: maintenanceTypeIcon(entry.key),
                    color: _typeColor(entry.key),
                    size: 32,
                    iconSize: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(entry.key,
                              style: context.text.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('${entry.value.toStringAsFixed(0)} DT',
                            style: context.text.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 4),
                      AnimatedBuilder(
                        animation: anim,
                        builder: (_, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: (maxVal > 0 ? entry.value / maxVal : 0) *
                                anim.value,
                            minHeight: 6,
                            backgroundColor: context.palette.border,
                            valueColor: AlwaysStoppedAnimation(
                                _typeColor(entry.key)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${countByType[entry.key] ?? 0} intervention${(countByType[entry.key] ?? 0) > 1 ? 's' : ''}',
                        style: context.text.labelSmall
                            ?.copyWith(color: context.palette.muted),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

// ── Vehicle rank card ─────────────────────────────────────────────────────────
class _VehicleRankCard extends StatelessWidget {
  final int rank;
  final VehicleAgg agg;
  final Animation<double> anim;
  final VoidCallback onTap;

  const _VehicleRankCard({
    required this.rank,
    required this.agg,
    required this.anim,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final medals = ['🥇', '🥈', '🥉'];
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(children: [
        // Medal
        SizedBox(
          width: 36,
          child: Text(medals[rank - 1],
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 24)),
        ),
        const SizedBox(width: 10),
        // Label + stats
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(agg.vehicleLabel,
                  style: context.text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              AnimatedBuilder(
                animation: anim,
                builder: (_, _) => Opacity(
                  opacity: anim.value,
                  child: Wrap(spacing: 10, children: [
                    _Pill('Coût : ${agg.totalCost.toStringAsFixed(0)} DT',
                        AppColors.success),
                    if (agg.totalDays > 0)
                      _Pill('${agg.totalDays} j immob.', AppColors.warning),
                    if (agg.totalImpact > agg.totalCost)
                      _Pill(
                          'Impact total : ${agg.totalImpact.toStringAsFixed(0)} DT',
                          AppColors.danger),
                  ]),
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right_rounded, color: context.palette.muted),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill(this.text, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

// Consistent color per maintenance type
Color _typeColor(String type) {
  final t = type.toLowerCase();
  if (t.contains('vidange')) return AppColors.success;
  if (t.contains('pneu') || t.contains('roue')) return AppColors.warning;
  if (t.contains('frein')) return AppColors.danger;
  if (t.contains('révision') || t.contains('revision')) return AppColors.info;
  if (t.contains('batterie') || t.contains('électr')) return AppColors.violet;
  return AppColors.brand;
}

