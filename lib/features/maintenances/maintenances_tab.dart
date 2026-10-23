import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/maintenance.dart';
import '../../repositories/maintenance_repository.dart';

class MaintenancesTab extends StatefulWidget {
  const MaintenancesTab({super.key});

  @override
  State<MaintenancesTab> createState() => _MaintenancesTabState();
}

class _MaintenancesTabState extends State<MaintenancesTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = MaintenanceRepository();

  late Future<List<MaintenanceView>> _future = _load();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _reload();
    });
  }

  MaintenanceStatus get _currentStatus => switch (_tabController.index) {
        0 => MaintenanceStatus.planifie,
        1 => MaintenanceStatus.enCours,
        _ => MaintenanceStatus.termine,
      };

  Future<List<MaintenanceView>> _load() =>
      _repo.getViewsByStatus(_currentStatus);

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openForm() async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.maintenanceForm,
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
              Tab(text: 'Planifiés'),
              Tab(text: 'En cours'),
              Tab(text: 'Terminés'),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<MaintenanceView>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LoadingView();
                }
                if (snap.hasError) {
                  return ErrorView(error: snap.error!, onRetry: _reload);
                }
                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const EmptyState(message: 'Aucun entretien.');
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ResponsiveCenter(
                    maxWidth: 900,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final m = item.maintenance;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor:
                                  Theme.of(context).colorScheme.primaryContainer,
                              child: const Icon(Icons.build_outlined),
                            ),
                            title: Text(
                              item.vehicleLabel,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Type : ${m.type} • Date : ${formatDate(m.date)}'),
                                if (m.description != null &&
                                    m.description!.isNotEmpty)
                                  Text(
                                    m.description!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                            trailing: maintenanceStatusChip(m.status),
                            isThreeLine: m.description != null &&
                                m.description!.isNotEmpty,
                            onTap: () async {
                              final changed = await Navigator.pushNamed(
                                context,
                                Routes.maintenanceDetail,
                                arguments: IdArgs(m.id!),
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
