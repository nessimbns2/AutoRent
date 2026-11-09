import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/session/session_manager.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/enums.dart';
import '../../models/rental.dart';
import '../../repositories/rental_repository.dart';
import 'widgets/rental_tile.dart';

class RentalsTab extends StatefulWidget {
  const RentalsTab({super.key});

  @override
  State<RentalsTab> createState() => _RentalsTabState();
}

class _RentalsTabState extends State<RentalsTab> {
  final _repo = RentalRepository();
  final _searchController = TextEditingController();

  static const _order = [
    RentalStatus.enCours,
    RentalStatus.reservee,
    RentalStatus.terminee,
    RentalStatus.annulee,
  ];

  RentalStatus _status = RentalStatus.enCours;
  bool _onlyMine = true;
  late Future<_RentalsData> _future = _load();

  Future<_RentalsData> _load() async {
    final user = SessionManager.instance.currentUser;
    final id = _onlyMine ? user?.id : null;
    final email = _onlyMine ? user?.email : null;
    final list = await _repo.getViewsByStatus(
      _status,
      userId: id,
      userEmail: email,
      search: _searchController.text,
    );
    final counts = await _repo.countByStatus(userId: id, userEmail: email);
    return _RentalsData(list, counts);
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _openForm() async {
    final saved = await Navigator.pushNamed(context, Routes.rentalForm);
    if (saved == true && mounted) _reload();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-rentals',
        onPressed: _openForm,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Location'),
      ),
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<_RentalsData>(
          future: _future,
          builder: (context, snap) {
            final counts = snap.data?.counts ?? const {};
            return Column(children: [
              PageHeader(
                title: 'Locations',
                subtitle: _onlyMine
                    ? 'Mes contrats et réservations'
                    : "Tous les contrats de l'agence",
                actions: [
                  _ScopeToggle(
                    onlyMine: _onlyMine,
                    onChanged: (v) {
                      _onlyMine = v;
                      _reload();
                    },
                  ),
                ],
              ),
              SearchField(
                controller: _searchController,
                hint: 'Client, véhicule ou immatriculation',
                onChanged: (_) => _reload(),
              ),
              PillTabs<RentalStatus>(
                selected: _status,
                onChanged: (s) {
                  _status = s;
                  _reload();
                },
                tabs: [
                  for (final s in _order)
                    PillTab(s, s.label, count: counts[s] ?? 0),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(child: _list(snap)),
            ]);
          },
        ),
      ),
    );
  }

  Widget _list(AsyncSnapshot<_RentalsData> snap) {
    if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _reload);
    if (!snap.hasData) return const LoadingView();
    final list = snap.data!.list;
    if (list.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'Aucune location',
        message: 'Aucun contrat « ${_status.label.toLowerCase()} » '
            '${_onlyMine ? 'pour vous' : 'dans l\'agence'}.',
        actionLabel: _status == RentalStatus.reservee ||
                _status == RentalStatus.enCours
            ? 'Nouvelle location'
            : null,
        onAction: _openForm,
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 2, 20, 96),
        itemCount: list.length,
        itemBuilder: (context, i) => RentalTile(
          view: list[i],
          onTap: () async {
            final changed = await Navigator.pushNamed(
              context,
              Routes.rentalDetail,
              arguments: IdArgs(list[i].rental.id!),
            );
            if (changed == true && mounted) _reload();
          },
        ),
      ),
    );
  }
}

class _ScopeToggle extends StatelessWidget {
  final bool onlyMine;
  final ValueChanged<bool> onChanged;
  const _ScopeToggle({required this.onlyMine, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, IconData icon, bool value) {
      final sel = onlyMine == value;
      return GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? AppColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                size: 15,
                color: sel ? Colors.white : context.palette.muted),
            const SizedBox(width: 4),
            Text(label,
                style: context.text.labelSmall?.copyWith(
                    color: sel ? Colors.white : context.palette.muted)),
          ]),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.palette.border),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        seg('Mes', Icons.person_rounded, true),
        seg('Toutes', Icons.groups_rounded, false),
      ]),
    );
  }
}

class _RentalsData {
  final List<RentalView> list;
  final Map<RentalStatus, int> counts;
  const _RentalsData(this.list, this.counts);
}
