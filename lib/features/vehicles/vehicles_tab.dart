import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/constants/business_rules.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/enums.dart';
import '../../models/vehicle.dart';
import '../../models/vehicle_document.dart';
import '../../repositories/vehicle_document_repository.dart';
import '../../repositories/vehicle_repository.dart';
import 'vehicle_export_actions.dart';
import 'widgets/vehicle_card.dart';

enum _Sort {
  name('Marque / modèle'),
  priceAsc('Prix croissant'),
  priceDesc('Prix décroissant'),
  yearDesc('Plus récents'),
  mileageAsc('Moins de kilomètres');

  const _Sort(this.label);
  final String label;
}

/// Multi-criteria filters of the fleet.
class _Filters {
  final Set<VehicleCategory> categories;
  final Set<FuelType> fuels;
  final Gearbox? gearbox;
  final int? minSeats;
  final RangeValues? price;
  final _Sort sort;

  const _Filters({
    this.categories = const {},
    this.fuels = const {},
    this.gearbox,
    this.minSeats,
    this.price,
    this.sort = _Sort.name,
  });

  int get activeCount =>
      (categories.isEmpty ? 0 : 1) +
      (fuels.isEmpty ? 0 : 1) +
      (gearbox == null ? 0 : 1) +
      (minSeats == null ? 0 : 1) +
      (price == null ? 0 : 1);

  bool matches(Vehicle v) =>
      (categories.isEmpty || categories.contains(v.category)) &&
      (fuels.isEmpty || fuels.contains(v.fuel)) &&
      (gearbox == null || v.gearbox == gearbox) &&
      (minSeats == null || (v.seats ?? 0) >= minSeats!) &&
      (price == null ||
          (v.pricePerDay >= price!.start && v.pricePerDay <= price!.end));
}

class VehiclesTab extends StatefulWidget {
  const VehiclesTab({super.key});

  @override
  State<VehiclesTab> createState() => _VehiclesTabState();
}

class _VehiclesTabState extends State<VehiclesTab> {
  final _repo = VehicleRepository();
  final _docRepo = VehicleDocumentRepository();
  final _searchController = TextEditingController();

  VehicleAvailability? _status; // null = all active vehicles
  _Filters _filters = const _Filters();
  late Future<_VehicleListData> _future = _load();

  Future<_VehicleListData> _load() async {
    final vehicles = await _repo.getAll(search: _searchController.text);
    final map = <int, VehicleAvailability>{};
    for (final v in vehicles) {
      if (v.id != null) map[v.id!] = await _repo.getAvailabilityState(v.id!);
    }
    // Worst document status per vehicle (expired > expiring soon).
    final docs = await _docRepo.all();
    final alerts = <int, DocumentStatus>{};
    docs.forEach((vehicleId, byType) {
      for (final d in byType.values) {
        final s = BusinessRules.documentStatus(d.expiresOn);
        if (s == DocumentStatus.expired) {
          alerts[vehicleId] = s;
        } else if (s == DocumentStatus.expiringSoon) {
          alerts.putIfAbsent(vehicleId, () => s);
        }
      }
    });
    return _VehicleListData(
      vehicles: vehicles,
      availabilities: map,
      documentAlerts: alerts,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

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
    final list = data.vehicles.where((v) {
      final a = data.availabilities[v.id];
      final statusOk = _status == null
          ? a != VehicleAvailability.archivee
          : a == _status;
      return statusOk && _filters.matches(v);
    }).toList();
    switch (_filters.sort) {
      case _Sort.priceAsc:
        list.sort((a, b) => a.pricePerDay.compareTo(b.pricePerDay));
      case _Sort.priceDesc:
        list.sort((a, b) => b.pricePerDay.compareTo(a.pricePerDay));
      case _Sort.yearDesc:
        list.sort((a, b) => (b.year ?? 0).compareTo(a.year ?? 0));
      case _Sort.mileageAsc:
        list.sort(
          (a, b) => (a.mileage ?? 1 << 30).compareTo(b.mileage ?? 1 << 30),
        );
      case _Sort.name:
        break; // already ordered by brand / model
    }
    return list;
  }

  Future<void> _openFilters(_VehicleListData data) async {
    final prices = data.vehicles.map((v) => v.pricePerDay).toList();
    final minP = prices.isEmpty ? 0.0 : prices.reduce((a, b) => a < b ? a : b);
    final maxP = prices.isEmpty ? 0.0 : prices.reduce((a, b) => a > b ? a : b);
    final result = await showModalBottomSheet<_Filters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FiltersSheet(
        initial: _filters,
        minPrice: minP.floorToDouble(),
        maxPrice: maxP.ceilToDouble(),
      ),
    );
    if (result != null && mounted) setState(() => _filters = result);
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
            data?.availabilities.values.forEach(
              (a) => counts[a] = (counts[a] ?? 0) + 1,
            );
            final active =
                (data?.vehicles.length ?? 0) -
                (counts[VehicleAvailability.archivee] ?? 0);

            return Column(
              children: [
                PageHeader(
                  title: 'Ma flotte',
                  subtitle: data == null
                      ? 'Chargement…'
                      : '$active véhicule(s) · ${counts[VehicleAvailability.disponible] ?? 0} disponible(s)',
                  actions: [
                    CircleIconButton(
                      icon: Icons.file_download_outlined,
                      tooltip: 'Exporter la flotte (CSV)',
                      onPressed: () => exportFleetCsv(context),
                    ),
                    CircleIconButton(
                      icon: Icons.tune_rounded,
                      tooltip: 'Filtres et tri',
                      badge: _filters.activeCount == 0
                          ? null
                          : _filters.activeCount,
                      onPressed: data == null ? null : () => _openFilters(data),
                    ),
                  ],
                ),
                SearchField(
                  controller: _searchController,
                  hint: 'Marque, modèle ou immatriculation',
                  onChanged: (_) => _reload(),
                ),
                PillTabs<VehicleAvailability?>(
                  selected: _status,
                  onChanged: (v) => setState(() => _status = v),
                  tabs: [
                    PillTab(null, 'Tous', count: data == null ? null : active),
                    for (final a in VehicleAvailability.values)
                      if (a != VehicleAvailability.archivee ||
                          (counts[a] ?? 0) > 0)
                        PillTab(a, a.label, count: counts[a] ?? 0),
                  ],
                ),
                if (_filters.activeCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_alt_rounded,
                          size: 16,
                          color: context.palette.muted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_filters.activeCount} filtre(s) actif(s)',
                            style: context.text.bodySmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(
                            () => _filters = _Filters(sort: _filters.sort),
                          ),
                          child: const Text('Effacer'),
                        ),
                      ],
                    ),
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
      final pristine =
          _searchController.text.isEmpty &&
          _status == null &&
          _filters.activeCount == 0;
      return EmptyState(
        icon: Icons.directions_car_filled_outlined,
        title: 'Aucun véhicule',
        message: pristine
            ? 'Ajoutez votre premier véhicule pour commencer.'
            : 'Aucun véhicule ne correspond à vos critères.',
        actionLabel: pristine ? 'Ajouter un véhicule' : null,
        onAction: pristine ? _openForm : null,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 230,
          mainAxisExtent: 262,
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
            documentAlert: data.documentAlerts[v.id],
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
  final Map<int, DocumentStatus> documentAlerts;
  _VehicleListData({
    required this.vehicles,
    required this.availabilities,
    required this.documentAlerts,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Filters bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _FiltersSheet extends StatefulWidget {
  final _Filters initial;
  final double minPrice;
  final double maxPrice;
  const _FiltersSheet({
    required this.initial,
    required this.minPrice,
    required this.maxPrice,
  });

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late Set<VehicleCategory> _categories = {...widget.initial.categories};
  late Set<FuelType> _fuels = {...widget.initial.fuels};
  late Gearbox? _gearbox = widget.initial.gearbox;
  late int? _minSeats = widget.initial.minSeats;
  late RangeValues _price =
      widget.initial.price ?? RangeValues(widget.minPrice, widget.maxPrice);
  late _Sort _sort = widget.initial.sort;

  bool get _priceFiltered =>
      _price.start > widget.minPrice || _price.end < widget.maxPrice;

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(t, style: context.text.titleSmall),
  );

  Widget _chip(String label, bool selected, VoidCallback onTap) => FilterChip(
    label: Text(label),
    selected: selected,
    showCheckmark: false,
    selectedColor: AppColors.brand.withValues(alpha: 0.14),
    labelStyle: context.text.labelMedium?.copyWith(
      color: selected ? AppColors.brand : null,
    ),
    onSelected: (_) => onTap(),
  );

  @override
  Widget build(BuildContext context) {
    final canFilterPrice = widget.maxPrice > widget.minPrice;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filtres et tri',
                            style: context.text.titleLarge,
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _categories = {};
                            _fuels = {};
                            _gearbox = null;
                            _minSeats = null;
                            _price = RangeValues(
                              widget.minPrice,
                              widget.maxPrice,
                            );
                            _sort = _Sort.name;
                          }),
                          child: const Text('Réinitialiser'),
                        ),
                      ],
                    ),
                    _title('Trier par'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in _Sort.values)
                          _chip(
                            s.label,
                            _sort == s,
                            () => setState(() => _sort = s),
                          ),
                      ],
                    ),
                    _title('Catégorie'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final c in VehicleCategory.values)
                          _chip(
                            c.label,
                            _categories.contains(c),
                            () => setState(() {
                              _categories.contains(c)
                                  ? _categories.remove(c)
                                  : _categories.add(c);
                            }),
                          ),
                      ],
                    ),
                    _title('Carburant'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final f in FuelType.values)
                          _chip(
                            f.label,
                            _fuels.contains(f),
                            () => setState(() {
                              _fuels.contains(f)
                                  ? _fuels.remove(f)
                                  : _fuels.add(f);
                            }),
                          ),
                      ],
                    ),
                    _title('Boîte de vitesses'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(
                          'Toutes',
                          _gearbox == null,
                          () => setState(() => _gearbox = null),
                        ),
                        for (final g in Gearbox.values)
                          _chip(
                            g.label,
                            _gearbox == g,
                            () => setState(() => _gearbox = g),
                          ),
                      ],
                    ),
                    _title('Places minimum'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _chip(
                          'Indifférent',
                          _minSeats == null,
                          () => setState(() => _minSeats = null),
                        ),
                        for (final n in const [4, 5, 7])
                          _chip(
                            '$n+',
                            _minSeats == n,
                            () => setState(() => _minSeats = n),
                          ),
                      ],
                    ),
                    if (canFilterPrice) ...[
                      _title(
                        'Prix par jour : ${_price.start.round()} – ${_price.end.round()} DT',
                      ),
                      RangeSlider(
                        values: _price,
                        min: widget.minPrice,
                        max: widget.maxPrice,
                        divisions: ((widget.maxPrice - widget.minPrice) / 5)
                            .ceil()
                            .clamp(1, 200),
                        labels: RangeLabels(
                          '${_price.start.round()} DT',
                          '${_price.end.round()} DT',
                        ),
                        onChanged: (r) => setState(() => _price = r),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Always visible, below the scrollable filters.
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Appliquer',
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(
                context,
                _Filters(
                  categories: _categories,
                  fuels: _fuels,
                  gearbox: _gearbox,
                  minSeats: _minSeats,
                  price: canFilterPrice && _priceFiltered ? _price : null,
                  sort: _sort,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
