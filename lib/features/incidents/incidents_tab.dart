import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/enums.dart';
import '../../models/incident.dart';
import '../../repositories/incident_repository.dart';
import 'widgets/incident_ui.dart';

class IncidentsTab extends StatefulWidget {
  const IncidentsTab({super.key});

  @override
  State<IncidentsTab> createState() => _IncidentsTabState();
}

class _IncidentsTabState extends State<IncidentsTab> {
  final _repo = IncidentRepository();

  IncidentStatus _status = IncidentStatus.enAttente;

  /// null = all types.
  IncidentType? _typeFilter;
  String _query = '';
  Timer? _searchDebounce;

  List<IncidentView> _items = const [];
  Map<IncidentStatus, int> _counts = {
    for (final s in IncidentStatus.values) s: 0,
  };
  bool _loading = true;
  Object? _error;

  /// Bumped after each load: used as the list key so the staggered entrance
  /// animation replays whenever the content changes.
  int _version = 0;
  int _loadToken = 0;

  bool _fabExtended = true;

  bool get _isFiltered => _typeFilter != null || _query.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final token = ++_loadToken;
    setState(() => _loading = true);
    try {
      // Counts ignore the filters so the selector always shows the real
      // workload per status.
      final results = await Future.wait([
        _repo.getViews(status: _status, type: _typeFilter, query: _query),
        _repo.countByStatus(),
      ]);
      if (!mounted || token != _loadToken) return;
      setState(() {
        _items = results[0] as List<IncidentView>;
        _counts = results[1] as Map<IncidentStatus, int>;
        _error = null;
        _loading = false;
        _version++;
      });
    } catch (e) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _selectStatus(IncidentStatus s) {
    if (s == _status) return;
    _status = s;
    _reload();
  }

  void _selectType(IncidentType? t) {
    if (t == _typeFilter) return;
    _typeFilter = t;
    _reload();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _query = value;
      _reload();
    });
  }

  Future<void> _openForm() async {
    final saved = await Navigator.pushNamed(context, Routes.incidentForm);
    if (saved == true && mounted) {
      // A new declaration always starts "en attente": show it there.
      _status = IncidentStatus.enAttente;
      _reload();
    }
  }

  Future<void> _openDetail(Incident inc) async {
    final changed = await Navigator.pushNamed(
      context,
      Routes.incidentDetail,
      arguments: IdArgs(inc.id!),
    );
    if (changed == true && mounted) _reload();
  }

  bool _onScroll(UserScrollNotification n) {
    final extended = n.direction != ScrollDirection.reverse;
    if (n.direction != ScrollDirection.idle && extended != _fabExtended) {
      setState(() => _fabExtended = extended);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        isExtended: _fabExtended,
        icon: const Icon(Icons.add_alert_rounded),
        label: const Text('Déclarer'),
      ),
      body: ResponsiveCenter(
        maxWidth: 900,
        child: Column(
          children: [
            _buildStatusSelector(),
            SearchField(
              hint: 'Rechercher (véhicule, lieu, locataire…)',
              onChanged: _onSearchChanged,
            ),
            _buildTypeFilter(),
            AnimatedOpacity(
              opacity: _loading ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const LinearProgressIndicator(minHeight: 2),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSelector() => Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Row(
          children: [
            for (final s in IncidentStatus.values) ...[
              Expanded(
                child: StatusSelectorCard(
                  status: s,
                  count: _counts[s] ?? 0,
                  selected: s == _status,
                  onTap: () => _selectStatus(s),
                ),
              ),
              if (s != IncidentStatus.values.last) const SizedBox(width: 8),
            ],
          ],
        ),
      );

  Widget _buildTypeFilter() {
    Widget chip(IncidentType? type, String label, IconData icon, Color color) {
      final selected = _typeFilter == type;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: Icon(icon, size: 18, color: selected ? Colors.white : color),
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          selectedColor: color,
          labelStyle: TextStyle(
            color: selected ? Colors.white : null,
            fontWeight: FontWeight.w600,
          ),
          shape: const StadiumBorder(),
          onSelected: (_) => _selectType(type),
        ),
      );
    }

    final primary = Theme.of(context).colorScheme.primary;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Row(
        children: [
          chip(null, 'Tous', Icons.apps_rounded, primary),
          chip(IncidentType.accident, 'Accidents', IncidentType.accident.icon,
              IncidentType.accident.color),
          chip(IncidentType.panne, 'Pannes', IncidentType.panne.icon,
              IncidentType.panne.color),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _items.isEmpty) {
      return ErrorView(error: _error!, onRetry: _reload);
    }
    if (_loading && _version == 0) return const LoadingView();

    final Widget content = _items.isEmpty
        ? ListView(
            // Scrollable so pull-to-refresh works on an empty list.
            key: ValueKey('empty-$_version'),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 40),
              EntranceAnimation(child: _EmptyIllustration(
                filtered: _isFiltered,
                status: _status,
              )),
            ],
          )
        : ListView.builder(
            key: ValueKey('list-$_version'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
            itemCount: _items.length,
            itemBuilder: (context, i) => EntranceAnimation(
              delay: EntranceAnimation.staggerDelay(i),
              child: _IncidentCard(
                item: _items[i],
                onTap: () => _openDetail(_items[i].incident),
              ),
            ),
          );

    return NotificationListener<UserScrollNotification>(
      onNotification: _onScroll,
      child: RefreshIndicator(
        onRefresh: _reload,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: content,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Incident card
// ─────────────────────────────────────────────────────────────────────────────
class _IncidentCard extends StatelessWidget {
  final IncidentView item;
  final VoidCallback onTap;
  const _IncidentCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final inc = item.incident;
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: scheme.surface,
        elevation: 0,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.7)),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Colored accent stripe
                  Container(width: 5, color: inc.type.color),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag: incidentHeroTag(inc.id!),
                            child: IncidentTypeBadge(type: inc.type),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${inc.type.label} #${inc.id}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: inc.type.color,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                    IncidentStatusPill(status: inc.status),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.vehicleLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    _Meta(
                                      icon: Icons.event_rounded,
                                      text: formatDate(inc.date),
                                      style: muted,
                                    ),
                                    _Meta(
                                      icon: Icons.place_rounded,
                                      text: inc.place,
                                      style: muted,
                                    ),
                                    if (inc.photos.isNotEmpty)
                                      _Meta(
                                        icon: Icons.photo_camera_rounded,
                                        text: '${inc.photos.length}',
                                        style: muted,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  item.clientName != null
                                      ? 'Locataire : ${item.clientName}'
                                      : inc.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: muted,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final TextStyle style;
  const _Meta({required this.icon, required this.text, required this.style});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: style.color),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(text,
                style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
}

class _EmptyIllustration extends StatelessWidget {
  final bool filtered;
  final IncidentStatus status;
  const _EmptyIllustration({required this.filtered, required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = filtered ? scheme.outline : status.color;
    return Column(
      children: [
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            filtered ? Icons.search_off_rounded : status.icon,
            size: 52,
            color: color,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          filtered ? 'Aucun résultat' : 'Aucun incident ${status.label.toLowerCase()}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            filtered
                ? 'Essayez un autre mot-clé ou un autre type.'
                : status == IncidentStatus.resolu
                    ? 'Les incidents résolus apparaîtront ici.'
                    : 'Tout roule ! Appuyez sur « Déclarer » pour signaler un problème.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
