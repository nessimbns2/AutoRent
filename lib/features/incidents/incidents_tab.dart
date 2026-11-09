import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/incident.dart';
import '../../repositories/incident_repository.dart';

class IncidentsTab extends StatefulWidget {
  const IncidentsTab({super.key});

  @override
  State<IncidentsTab> createState() => _IncidentsTabState();
}

class _IncidentsTabState extends State<IncidentsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = IncidentRepository();

  late Future<List<IncidentView>> _future = _load();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _reload();
    });
  }

  IncidentStatus get _currentStatus => switch (_tabController.index) {
        0 => IncidentStatus.enAttente,
        1 => IncidentStatus.enCours,
        _ => IncidentStatus.resolu,
      };

  Future<List<IncidentView>> _load() => _repo.getViewsByStatus(_currentStatus);

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openForm() async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.incidentForm,
    );
    if (saved == true && mounted) _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openForm,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'En attente'),
              Tab(text: 'En cours'),
              Tab(text: 'Résolus'),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<IncidentView>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LoadingView();
                }
                if (snap.hasError) {
                  return ErrorView(error: snap.error!, onRetry: _reload);
                }
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const EmptyState(message: 'Aucun incident.');
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ResponsiveCenter(
                    maxWidth: 900,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final inc = item.incident;
                        final isAccident = inc.type == IncidentType.accident;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isAccident
                                  ? Colors.red.withValues(alpha: 0.15)
                                  : Colors.orange.withValues(alpha: 0.15),
                              child: Icon(
                                isAccident
                                    ? Icons.car_crash_outlined
                                    : Icons.build_outlined,
                                color: isAccident ? Colors.red : Colors.orange,
                              ),
                            ),
                            title: Text(
                              item.vehicleLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  '${inc.type.label} • ${formatDate(inc.date)} • ${inc.place}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  inc.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                            trailing: incidentStatusChip(inc.status),
                            isThreeLine: true,
                            onTap: () async {
                              final changed = await Navigator.pushNamed(
                                context,
                                Routes.incidentDetail,
                                arguments: IdArgs(inc.id!),
                              );
                              if (changed == true && mounted) _reload();
                            },
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
