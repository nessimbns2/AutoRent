import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/constants/strings.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/enums.dart';
import '../../models/incident.dart';
import '../../repositories/incident_repository.dart';
import 'incident_stats_screen.dart';
import 'widgets/incident_sheets.dart';
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

  Future<void> _openStats() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const IncidentStatsScreen()),
    );
    // Statuses may have changed from incidents opened on the dashboard.
    if (mounted) _reload();
  }

  Future<void> _openEdit(Incident inc) async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.incidentForm,
      arguments: IncidentFormArgs(
        incidentId: inc.id,
        vehicleId: inc.vehicleId,
        rentalId: inc.rentalId,
      ),
    );
    if (saved == true && mounted) _reload();
  }

  /// Applies a status change; returns true when it succeeded.
  Future<bool> _setStatus(Incident inc, IncidentStatus status) async {
    if (status == inc.status) return false;
    try {
      await _repo.changeStatus(
        inc.id!,
        status,
        byUserId: SessionManager.instance.currentUser?.id,
      );
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Erreur lors du changement de statut : $e');
      }
      return false;
    }
    if (mounted) {
      showSnack(context, '${inc.type.label} #${inc.id} → ${status.label}');
    }
    return true;
  }

  /// Asks for confirmation then deletes; returns true when deleted.
  Future<bool> _confirmAndDelete(Incident inc) async {
    if (!await confirmDeleteIncident(context, inc)) return false;
    try {
      await _repo.delete(inc.id!);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
      return false;
    } catch (e) {
      if (mounted) showSnack(context, 'Erreur lors de la suppression : $e');
      return false;
    }
    if (mounted) showSnack(context, Strings.incidentDeleted);
    return true;
  }

  /// Swipe on a card: right = next status, left = delete. Returning true
  /// lets the card slide out (it no longer belongs to this status list).
  Future<bool> _onSwipe(IncidentView item, DismissDirection dir) async {
    final inc = item.incident;
    if (dir == DismissDirection.startToEnd) {
      final next = inc.status.next;
      return next != null && await _setStatus(inc, next);
    }
    return _confirmAndDelete(inc);
  }

  void _afterSwipe(IncidentView item) {
    setState(() {
      _items = [..._items]..remove(item);
    });
    _refreshCounts();
  }

  Future<void> _refreshCounts() async {
    try {
      final counts = await _repo.countByStatus();
      if (mounted) setState(() => _counts = counts);
    } catch (_) {
      // Counts are cosmetic; a full reload will fix them.
    }
  }

  Future<void> _showActions(IncidentView item) async {
    final inc = item.incident;
    final action = await showIncidentActionsSheet(context, item);
    if (!mounted || action == null) return;
    switch (action) {
      case IncidentAction.open:
        await _openDetail(inc);
      case IncidentAction.edit:
        await _openEdit(inc);
      case IncidentAction.changeStatus:
        final s = await showStatusPickerSheet(context, inc.status);
        if (s != null && await _setStatus(inc, s)) _reload();
      case IncidentAction.delete:
        if (await _confirmAndDelete(inc)) _reload();
    }
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
        icon: const Icon(Icons.add_alert_rounded, size: 20),
        label: const Text('Déclarer'),
      ),
      body: ResponsiveCenter(
        maxWidth: 900,
        child: Column(
          children: [
            _buildStatusSelector(),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                children: [
                  Expanded(
                    child: _IncidentSearchBar(
                      onChanged: _onSearchChanged,
                      resultCount: _query.trim().isEmpty || _loading
                          ? null
                          : _items.length,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Tooltip(
                      message: 'Suivi des incidents',
                      child: Material(
                        color: IncidentPalette.brown,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: _openStats,
                          child: const SizedBox(
                            width: 52,
                            height: 52,
                            child: Icon(
                              Icons.insights_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(alignment: Alignment.centerLeft, child: _buildTypeFilter()),
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
          side: BorderSide(
            color: selected ? color : color.withValues(alpha: 0.35),
          ),
          labelStyle: TextStyle(
            color: selected ? Colors.white : color,
            fontWeight: FontWeight.w700,
          ),
          shape: const StadiumBorder(),
          onSelected: (_) => _selectType(type),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          chip(null, 'Tous', Icons.apps_rounded, IncidentPalette.brown),
          chip(
            IncidentType.accident,
            'Accidents',
            IncidentType.accident.icon,
            IncidentType.accident.color,
          ),
          chip(
            IncidentType.panne,
            'Pannes',
            IncidentType.panne.icon,
            IncidentType.panne.color,
          ),
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
              EntranceAnimation(
                child: _EmptyIllustration(
                  filtered: _isFiltered,
                  status: _status,
                ),
              ),
            ],
          )
        : ListView.builder(
            key: ValueKey('list-$_version'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
            itemCount: _items.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) return _SwipeHint(status: _status);
              final item = _items[i - 1];
              return EntranceAnimation(
                key: ValueKey(item.incident.id),
                delay: EntranceAnimation.staggerDelay(i - 1),
                child: _SwipeableIncidentCard(
                  item: item,
                  onTap: () => _openDetail(item.incident),
                  onLongPress: () => _showActions(item),
                  confirmSwipe: (dir) => _onSwipe(item, dir),
                  onSwiped: () => _afterSwipe(item),
                ),
              );
            },
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
// Search bar: filled pill, brown focus ring, clear button, result count
// ─────────────────────────────────────────────────────────────────────────────
class _IncidentSearchBar extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final int? resultCount;
  const _IncidentSearchBar({required this.onChanged, this.resultCount});

  @override
  State<_IncidentSearchBar> createState() => _IncidentSearchBarState();
}

class _IncidentSearchBarState extends State<_IncidentSearchBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focused = _focus.hasFocus;
    final hasText = _controller.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 52,
        decoration: BoxDecoration(
          color: focused ? scheme.surface : scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: focused ? IncidentPalette.brown : Colors.transparent,
            width: 1.6,
          ),
          boxShadow: focused
              ? [
                  BoxShadow(
                    color: IncidentPalette.brown.withValues(alpha: 0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search_rounded,
              size: 22,
              color: focused ? IncidentPalette.brown : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onChanged: (v) {
                  setState(() {});
                  widget.onChanged(v);
                },
                decoration: InputDecoration(
                  hintText: 'Véhicule, plaque, lieu, locataire…',
                  hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isCollapsed: true,
                ),
                style: const TextStyle(fontSize: 15.5),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.resultCount == null
                  ? const SizedBox.shrink()
                  : Container(
                      key: ValueKey(widget.resultCount),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: IncidentPalette.brown.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.resultCount} résultat${widget.resultCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: IncidentPalette.brown,
                        ),
                      ),
                    ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: hasText
                  ? IconButton(
                      key: const ValueKey('clear'),
                      tooltip: 'Effacer',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _clear,
                    )
                  : const SizedBox(key: ValueKey('none'), width: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipe hint shown above the list
// ─────────────────────────────────────────────────────────────────────────────
class _SwipeHint extends StatefulWidget {
  final IncidentStatus status;
  const _SwipeHint({required this.status});

  /// Hidden for the rest of the session once closed.
  static bool dismissed = false;

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final next = widget.status.next;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: _SwipeHint.dismissed
          ? const SizedBox(width: double.infinity)
          : Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              decoration: BoxDecoration(
                color: IncidentPalette.brown.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.swipe_rounded,
                    size: 20,
                    color: IncidentPalette.brown,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      next != null
                          ? 'Glissez → pour passer « ${next.label} », ← pour supprimer. Appui long : plus d\'actions.'
                          : 'Glissez ← pour supprimer. Appui long : plus d\'actions.',
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurface),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () =>
                        setState(() => _SwipeHint.dismissed = true),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Swipeable card: → next status, ← delete
// ─────────────────────────────────────────────────────────────────────────────
class _SwipeableIncidentCard extends StatelessWidget {
  final IncidentView item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<bool> Function(DismissDirection) confirmSwipe;
  final VoidCallback onSwiped;

  const _SwipeableIncidentCard({
    required this.item,
    required this.onTap,
    required this.onLongPress,
    required this.confirmSwipe,
    required this.onSwiped,
  });

  @override
  Widget build(BuildContext context) {
    final next = item.incident.status.next;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Dismissible(
        key: ValueKey('dismiss-${item.incident.id}'),
        direction: next == null
            ? DismissDirection.endToStart
            : DismissDirection.horizontal,
        dismissThresholds: const {
          DismissDirection.startToEnd: 0.35,
          DismissDirection.endToStart: 0.35,
        },
        background: next == null
            ? const SizedBox.shrink()
            : _SwipeBackground(
                color: next.color,
                icon: next.icon,
                label: next == IncidentStatus.enCours
                    ? 'Prendre en charge'
                    : 'Résolu',
                alignStart: true,
              ),
        secondaryBackground: const _SwipeBackground(
          color: IncidentPalette.danger,
          icon: Icons.delete_outline_rounded,
          label: 'Supprimer',
          alignStart: false,
        ),
        confirmDismiss: confirmSwipe,
        onDismissed: (_) => onSwiped(),
        child: _IncidentCard(
          item: item,
          onTap: onTap,
          onLongPress: onLongPress,
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final bool alignStart;
  const _SwipeBackground({
    required this.color,
    required this.icon,
    required this.label,
    required this.alignStart,
  });

  @override
  Widget build(BuildContext context) {
    final content = [
      Icon(icon, size: 22, color: Colors.white),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: alignStart ? Alignment.centerLeft : Alignment.centerRight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: alignStart ? content : content.reversed.toList(),
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
  final VoidCallback onLongPress;
  const _IncidentCard({
    required this.item,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final inc = item.incident;
    final scheme = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant);

    return Material(
      color: scheme.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                                    text: relativeDate(inc.date),
                                    style: muted,
                                  ),
                                  _Meta(
                                    icon: Icons.place_rounded,
                                    text: inc.place,
                                    style: muted,
                                  ),
                                ],
                              ),
                              if (item.clientName != null) ...[
                                const SizedBox(height: 6),
                                _Meta(
                                  icon: Icons.person_rounded,
                                  text: item.clientName!,
                                  style: muted.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                inc.description,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: muted,
                              ),
                              if (inc.photos.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                _PhotoThumbs(photos: inc.photos),
                              ],
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
    );
  }
}

/// Up to 3 thumbnails, then "+N".
class _PhotoThumbs extends StatelessWidget {
  final List<String> photos;
  const _PhotoThumbs({required this.photos});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shown = photos.take(3).toList();
    final extra = photos.length - shown.length;
    return Row(
      children: [
        for (final p in shown)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CarImage(fileName: p, width: 46, height: 46),
            ),
          ),
        if (extra > 0)
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '+$extra',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
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
        child: Text(
          text,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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
          alignment: Alignment.center,
          child: Icon(
            filtered ? Icons.search_off_rounded : status.icon,
            size: 50,
            color: color,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          filtered
              ? 'Aucun résultat'
              : 'Aucun incident ${status.label.toLowerCase()}',
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
