import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/maintenance.dart';
import '../../repositories/maintenance_repository.dart';
import '../rentals/widgets/rental_tile.dart';

/// Maintenance list with status filters — embedded in the "Suivi" tab.
class MaintenancesList extends StatefulWidget {
  final int refreshToken;
  const MaintenancesList({super.key, this.refreshToken = 0});

  @override
  State<MaintenancesList> createState() => _MaintenancesListState();
}

class _MaintenancesListState extends State<MaintenancesList> {
  final _repo = MaintenanceRepository();
  MaintenanceStatus _status = MaintenanceStatus.planifie;
  late Future<_Data> _future = _load();

  Future<_Data> _load() async =>
      _Data(await _repo.getViewsByStatus(_status), await _repo.countByStatus());

  void _reload() => setState(() { _future = _load(); });

  @override
  void didUpdateWidget(covariant MaintenancesList old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Data>(
      future: _future,
      builder: (context, snap) {
        final counts = snap.data?.counts ?? const {};
        return Column(children: [
          PillTabs<MaintenanceStatus>(
            selected: _status,
            onChanged: (s) {
              _status = s;
              _reload();
            },
            tabs: [
              for (final s in MaintenanceStatus.values)
                PillTab(s, s.label, count: counts[s] ?? 0),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(child: _list(snap)),
        ]);
      },
    );
  }

  Widget _list(AsyncSnapshot<_Data> snap) {
    if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
    if (!snap.hasData) return const LoadingView();
    final items = snap.data!.items;
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.build_circle_outlined,
        title: 'Rien à signaler',
        message: 'Aucun entretien « ${_status.label.toLowerCase()} ».',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 96),
        itemCount: items.length,
        itemBuilder: (context, i) => MaintenanceTile(
          view: items[i],
          onTap: () async {
            final changed = await Navigator.pushNamed(
              context,
              Routes.maintenanceDetail,
              arguments: IdArgs(items[i].maintenance.id!),
            );
            if (changed == true && mounted) _reload();
          },
        ),
      ),
    );
  }
}

class MaintenanceTile extends StatelessWidget {
  final MaintenanceView view;
  final VoidCallback onTap;
  final bool showVehicle;
  const MaintenanceTile({
    super.key,
    required this.view,
    required this.onTap,
    this.showVehicle = true,
  });

  @override
  Widget build(BuildContext context) {
    final m = view.maintenance;
    final color = maintenanceStatusColor(m.status);
    final late = m.status == MaintenanceStatus.planifie &&
        DateUtils.dateOnly(m.date).isBefore(DateUtils.dateOnly(DateTime.now()));
    final (name, plate) = splitVehicleLabel(view.vehicleLabel);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: maintenanceTypeIcon(m.type), color: color, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                      child: Text(m.type, style: context.text.titleSmall)),
                  maintenanceStatusChip(m.status),
                ]),
                if (showVehicle)
                  Text('$name · $plate',
                      style: context.text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Row(children: [
                  Icon(Icons.event_rounded,
                      size: 14,
                      color: late ? AppColors.danger : context.palette.muted),
                  const SizedBox(width: 4),
                  Text(
                    '${formatShortDate(m.date)} · ${relativeDay(m.date)}',
                    style: context.text.labelSmall?.copyWith(
                        color: late ? AppColors.danger : context.palette.muted),
                  ),
                ]),
                if (m.description != null && m.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(m.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Data {
  final List<MaintenanceView> items;
  final Map<MaintenanceStatus, int> counts;
  const _Data(this.items, this.counts);
}
