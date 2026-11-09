import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/enums.dart';
import '../../models/vehicle.dart';
import '../../repositories/vehicle_repository.dart';
import 'widgets/vehicle_card.dart';

enum _Sort { name, priceAsc, priceDesc }

class VehiclesTab extends StatefulWidget {
  const VehiclesTab({super.key});

  @override
  State<VehiclesTab> createState() => _VehiclesTabState();
}

class _VehiclesTabState extends State<VehiclesTab> {
  final _repo = VehicleRepository();
  final _searchController = TextEditingController();

  VehicleAvailability? _filter; // null = all
  _Sort _sort = _Sort.name;
  late Future<_VehicleListData> _future = _load();

  Future<_VehicleListData> _load() async {
    final vehicles = await _repo.getAll(search: _searchController.text);
    final map = <int, VehicleAvailability>{};
    for (final v in vehicles) {
      if (v.id != null) map[v.id!] = await _repo.getAvailabilityState(v.id!);
    }
    return _VehicleListData(vehicles: vehicles, availabilities: map);
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _openForm() async {
    final saved = await Navigator.pushNamed(context, Routes.vehicleForm);
    if (saved == true && mounted) _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Vehicle> _visible(_VehicleListData data) {
    final list = data.vehicles
        .where((v) => _filter == null || data.availabilities[v.id] == _filter)
        .toList();
    switch (_sort) {
      case _Sort.priceAsc:
        list.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
      case _Sort.priceDesc:
        list.sort((a, b) => b.pricePerDay.compareTo(a.pricePerDay));
      case _Sort.name:
        break; // already ordered by brand / model
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-vehicles',
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Véhicule'),
      ),
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_VehicleListData>(
          future: _future,
          builder: (context, snap) {
            final data = snap.data;
            final counts = <VehicleAvailability, int>{};
            data?.availabilities.values
                .forEach((a) => counts[a] = (counts[a] ?? 0) + 1);

            return Column(
              children: [
                PageHeader(
                  title: 'Ma flotte',
                  subtitle: data == null
                      ? 'Chargement…'
                      : '${data.vehicles.length} véhicule(s) · ${counts[VehicleAvailability.disponible] ?? 0} disponible(s)',
                  actions: [
                    PopupMenuButton<_Sort>(
                      tooltip: 'Trier',
                      position: PopupMenuPosition.under,
                      initialValue: _sort,
                      onSelected: (s) => setState(() => _sort = s),
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: _Sort.name, child: Text('Marque / modèle')),
                        PopupMenuItem(
                            value: _Sort.priceAsc,
                            child: Text('Prix croissant')),
                        PopupMenuItem(
                            value: _Sort.priceDesc,
                            child: Text('Prix décroissant')),
                      ],
                      child: const IgnorePointer(
                        child: CircleIconButton(icon: Icons.tune_rounded),
                      ),
                    ),
                  ],
                ),
                SearchField(
                  controller: _searchController,
                  hint: 'Marque, modèle ou immatriculation',
                  onChanged: (_) => _reload(),
                ),
                PillTabs<VehicleAvailability?>(
                  selected: _filter,
                  onChanged: (v) => setState(() => _filter = v),
                  tabs: [
                    PillTab(null, 'Tous', count: data?.vehicles.length),
                    for (final a in VehicleAvailability.values)
                      PillTab(a, a.label, count: counts[a] ?? 0),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(child: _body(snap)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(AsyncSnapshot<_VehicleListData> snap) {
    if (snap.hasError) {
      return ErrorView(error: snap.error!, onRetry: _reload);
    }
    // Keep showing the previous results while a new search is running.
    if (!snap.hasData) return const LoadingView();
    final data = snap.data!;
    final vehicles = _visible(data);
    if (vehicles.isEmpty) {
      return EmptyState(
        icon: Icons.directions_car_filled_outlined,
        title: 'Aucun véhicule',
        message: _searchController.text.isEmpty && _filter == null
            ? 'Ajoutez votre premier véhicule pour commencer.'
            : 'Aucun véhicule ne correspond à vos critères.',
        actionLabel: _filter == null ? 'Ajouter un véhicule' : null,
        onAction: _filter == null ? _openForm : null,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 230,
          mainAxisExtent: 246,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: vehicles.length,
        itemBuilder: (context, index) {
          final v = vehicles[index];
          return VehicleCard(
            vehicle: v,
            availability:
                data.availabilities[v.id] ?? VehicleAvailability.disponible,
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
      ),
    );
  }
}

class _VehicleListData {
  final List<Vehicle> vehicles;
  final Map<int, VehicleAvailability> availabilities;
  _VehicleListData({required this.vehicles, required this.availabilities});
}
