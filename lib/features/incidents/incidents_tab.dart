import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/incident.dart';
import '../../repositories/incident_repository.dart';
import '../rentals/widgets/rental_tile.dart';

/// Incident list with status filters — embedded in the "Suivi" tab.
class IncidentsList extends StatefulWidget {
  final int refreshToken;
  const IncidentsList({super.key, this.refreshToken = 0});

  @override
  State<IncidentsList> createState() => _IncidentsListState();
}

class _IncidentsListState extends State<IncidentsList> {
  final _repo = IncidentRepository();
  IncidentStatus _status = IncidentStatus.enAttente;
  late Future<_Data> _future = _load();

  Future<_Data> _load() async =>
      _Data(await _repo.getViewsByStatus(_status), await _repo.countByStatus());

  void _reload() => setState(() { _future = _load(); });

  @override
  void didUpdateWidget(covariant IncidentsList old) {
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
          PillTabs<IncidentStatus>(
            selected: _status,
            onChanged: (s) {
              _status = s;
              _reload();
            },
            tabs: [
              for (final s in IncidentStatus.values)
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
        icon: Icons.verified_user_outlined,
        title: 'Aucun incident',
        message: 'Aucun incident « ${_status.label.toLowerCase()} ».',
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 96),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          final inc = item.incident;
          final (name, plate) = splitVehicleLabel(item.vehicleLabel);
          return AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            onTap: () async {
              final changed = await Navigator.pushNamed(
                context,
                Routes.incidentDetail,
                arguments: IdArgs(inc.id!),
              );
              if (changed == true && mounted) _reload();
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(
                    icon: incidentTypeIcon(inc.type),
                    color: incidentTypeColor(inc.type),
                    size: 46),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text('${inc.type.label} · $name',
                              style: context.text.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        incidentStatusChip(inc.status),
                      ]),
                      Text(plate, style: context.text.bodySmall),
                      const SizedBox(height: 6),
                      Text(inc.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodyMedium),
                      const SizedBox(height: 8),
                      Wrap(spacing: 12, runSpacing: 4, children: [
                        _meta(context, Icons.place_outlined, inc.place),
                        _meta(context, Icons.event_rounded,
                            formatShortDate(inc.date)),
                        if (inc.photos.isNotEmpty)
                          _meta(context, Icons.photo_library_outlined,
                              '${inc.photos.length} photo(s)'),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.palette.muted),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(text,
                style: context.text.labelSmall
                    ?.copyWith(color: context.palette.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}

class _Data {
  final List<IncidentView> items;
  final Map<IncidentStatus, int> counts;
  const _Data(this.items, this.counts);
}
