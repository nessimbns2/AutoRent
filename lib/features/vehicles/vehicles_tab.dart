import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/enums.dart';
import '../../models/vehicle.dart';
import '../../repositories/vehicle_repository.dart';
import 'widgets/vehicle_card.dart';

class VehiclesTab extends StatefulWidget {
  const VehiclesTab({super.key});

  @override
  State<VehiclesTab> createState() => _VehiclesTabState();
}

class _VehiclesTabState extends State<VehiclesTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = VehicleRepository();
  final _searchController = TextEditingController();

  late Future<_VehicleListData> _future = _load();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _reload();
    });
  }

  bool? get _currentFilter => switch (_tabController.index) {
        1 => true,
        2 => false,
        _ => null,
      };

  Future<_VehicleListData> _load() async {
    final vehicles = await _repo.getAll(
      availableOnly: _currentFilter,
      search: _searchController.text,
    );
    final map = <int, VehicleAvailability>{};
    for (final v in vehicles) {
      if (v.id != null) {
        map[v.id!] = await _repo.getAvailabilityState(v.id!);
      }
    }
    return _VehicleListData(vehicles: vehicles, availabilities: map);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openForm() async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.vehicleForm,
    );
    if (saved == true && mounted) _reload();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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
              Tab(text: 'Tous'),
              Tab(text: 'Disponibles'),
              Tab(text: 'Indisponibles'),
            ],
          ),
          SearchField(
            hint: 'Rechercher par marque, modèle ou immatriculation',
            onChanged: (_) => _reload(),
          ),
          Expanded(
            child: FutureBuilder<_VehicleListData>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const LoadingView();
                }
                if (snap.hasError) {
                  return ErrorView(error: snap.error!, onRetry: _reload);
                }
                final data = snap.data!;
                final vehicles = data.vehicles;
                if (vehicles.isEmpty) {
                  return const EmptyState(message: 'Aucun véhicule trouvé.');
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      int crossAxisCount = 2;
                      if (width >= 1200) {
                        crossAxisCount = 5;
                      } else if (width >= 900) {
                        crossAxisCount = 4;
                      } else if (width >= 600) {
                        crossAxisCount = 3;
                      }
                      final childAspectRatio = width < 380
                          ? 0.72
                          : (width < 600 ? 0.78 : 0.85);

                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: childAspectRatio,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: vehicles.length,
                        itemBuilder: (context, index) {
                          final v = vehicles[index];
                          final avail = data.availabilities[v.id] ??
                              VehicleAvailability.disponible;
                          return VehicleCard(
                            vehicle: v,
                            availability: avail,
                            onTap: () async {
                              final changed = await Navigator.pushNamed(
                                context,
                                Routes.vehicleDetail,
                                arguments: IdArgs(v.id!),
                              );
                              if (changed == true && mounted) _reload();
                            },
                          );
                        },
                      );
                    },
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

class _VehicleListData {
  final List<Vehicle> vehicles;
  final Map<int, VehicleAvailability> availabilities;
  _VehicleListData({required this.vehicles, required this.availabilities});
}
