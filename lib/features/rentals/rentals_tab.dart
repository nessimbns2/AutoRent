import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/rental.dart';
import '../../repositories/rental_repository.dart';

class RentalsTab extends StatefulWidget {
  const RentalsTab({super.key});

  @override
  State<RentalsTab> createState() => _RentalsTabState();
}

class _RentalsTabState extends State<RentalsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _repo = RentalRepository();
  bool _onlyMyRentals = true;

  late Future<List<RentalView>> _future = _load();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      _reload();
    });
  }

  RentalStatus get _currentStatus => switch (_tabController.index) {
        0 => RentalStatus.reservee,
        1 => RentalStatus.enCours,
        2 => RentalStatus.terminee,
        _ => RentalStatus.annulee,
      };

  Future<List<RentalView>> _load() {
    final user = SessionManager.instance.currentUser;
    return _repo.getViewsByStatus(
      _currentStatus,
      userId: _onlyMyRentals ? user?.id : null,
      userEmail: _onlyMyRentals ? user?.email : null,
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _openForm() async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.rentalForm,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _onlyMyRentals ? 'Mes réservations' : 'Toutes les locations',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                FilterChip(
                  avatar: Icon(
                    _onlyMyRentals ? Icons.person : Icons.group,
                    size: 16,
                  ),
                  label: Text(_onlyMyRentals ? 'Mes locations' : 'Toutes'),
                  selected: _onlyMyRentals,
                  onSelected: (val) {
                    setState(() {
                      _onlyMyRentals = val;
                      _reload();
                    });
                  },
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Réservées'),
              Tab(text: 'En cours'),
              Tab(text: 'Terminées'),
              Tab(text: 'Annulées'),
            ],
          ),
          Expanded(
            child: FutureBuilder<List<RentalView>>(
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
                  return const EmptyState(message: 'Aucune location.');
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
                        final r = item.rental;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final changed = await Navigator.pushNamed(
                                context,
                                Routes.rentalDetail,
                                arguments: IdArgs(r.id!),
                              );
                              if (changed == true && mounted) _reload();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.vehicleLabel,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      rentalStatusChip(r.status),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_outline, size: 16),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          item.clientName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Row(
                                          children: [
                                            const Icon(
                                                Icons.calendar_today_outlined,
                                                size: 16),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '${formatDate(r.startDate)} → ${formatDate(r.endDate)} (${r.days} j)',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        formatMoney(r.totalPrice),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
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
