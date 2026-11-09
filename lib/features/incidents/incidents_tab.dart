import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme.dart';

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

/// Incident list with status cards, search and filters — embedded in the
/// "Suivi" tab, which owns the "Déclarer" button. [refreshToken] changes after
/// a declaration made from that button.
class IncidentsList extends StatefulWidget {
  final int refreshToken;
  const IncidentsList({super.key, this.refreshToken = 0});

  @override
  State<IncidentsList> createState() => _IncidentsListState();
}

class _IncidentsListState extends State<IncidentsList> {
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

  bool get _isFiltered => _typeFilter != null || _query.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void didUpdateWidget(covariant IncidentsList old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) {
      // A new declaration always starts "en attente": show it there.
      _status = IncidentStatus.enAttente;
      _reload();
    }
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

  @override
  Widget build(BuildContext context) {
    return ResponsiveCenter(
      maxWidth: 900,
      child: Column(
        children: [
          _buildStatusSelector(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
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
                const SizedBox(width: 10),
                _StatsButton(onTap: _openStats),
              ],
            ),
          ),
          PillTabs<IncidentType?>(
            selected: _typeFilter,
            onChanged: _selectType,
            tabs: [
              const PillTab(null, 'Tous', icon: Icons.apps_rounded),
              PillTab(
                IncidentType.accident,
                'Accidents',
                icon: IncidentType.accident.icon,
              ),
              PillTab(
                IncidentType.panne,
                'Pannes',
                icon: IncidentType.panne.icon,
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedOpacity(
            opacity: _loading && _version > 0 ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: const LinearProgressIndicator(
              minHeight: 2,
              color: AppColors.brand,
              backgroundColor: Colors.transparent,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildStatusSelector() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
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
          if (s != IncidentStatus.values.last) const SizedBox(width: 10),
        ],
      ],
    ),
  );

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
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
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

    return RefreshIndicator(
        onRefresh: _reload,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: content,
        ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Search field in the app style (surface fill, soft border, orange focus),
// with a clear button and the result count.
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
    final focused = _focus.hasFocus;
    final hasText = _controller.text.isNotEmpty;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md + 2),
        border: Border.all(
          color: focused ? AppColors.brand : context.palette.border,
          width: focused ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: focused
                ? AppColors.brand.withValues(alpha: 0.14)
                : context.palette.cardShadow,
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            size: 22,
            color: focused ? AppColors.brand : context.palette.muted,
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
                hintStyle: context.text.bodyMedium?.copyWith(
                  color: context.palette.muted,
                ),
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
              ),
              style: context.text.bodyMedium,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: widget.resultCount == null
                ? const SizedBox.shrink()
                : StatusChip(
                    key: ValueKey(widget.resultCount),
                    label:
                        '${widget.resultCount} résultat${widget.resultCount == 1 ? '' : 's'}',
                    color: AppColors.brand,
                  ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
            child: hasText
                ? IconButton(
                    key: const ValueKey('clear'),
                    tooltip: 'Effacer',
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _clear,
                  )
                : const SizedBox(key: ValueKey('none'), width: 12),
          ),
        ],
      ),
    );
  }
}

/// Navy square opening the follow-up dashboard (orange in dark mode).
class _StatsButton extends StatelessWidget {
  final VoidCallback onTap;
  const _StatsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = context.isDark ? AppColors.brand : AppColors.ink;
    return Tooltip(
      message: 'Suivi des incidents',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
          boxShadow: [
            BoxShadow(
              color: bg.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md + 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md + 2),
            onTap: onTap,
            child: const SizedBox(
              width: 52,
              height: 52,
              child: Icon(Icons.insights_rounded, color: Colors.white),
            ),
          ),
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
    final next = widget.status.next;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      child: _SwipeHint.dismissed
          ? const SizedBox(width: double.infinity)
          : Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              decoration: BoxDecoration(
                color: context.palette.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  const IconBadge(
                    icon: Icons.swipe_rounded,
                    color: AppColors.brand,
                    size: 32,
                    iconSize: 17,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      next != null
                          ? 'Glissez → pour passer « ${next.label} », ← pour supprimer. Appui long : plus d\'actions.'
                          : 'Glissez ← pour supprimer. Appui long : plus d\'actions.',
                      style: context.text.bodySmall,
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: context.palette.muted,
                    ),
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
      padding: const EdgeInsets.only(bottom: 14),
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
          color: AppColors.danger,
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
        style: context.text.labelLarge?.copyWith(color: Colors.white),
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
// Incident card (AppCard): type badge, vehicle, status, place / date, renter,
// description and photos.
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
    final muted = context.text.bodySmall!;

    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: incidentHeroTag(inc.id!),
                child: IncidentTypeBadge(type: inc.type, size: 46),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.vehicleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${inc.type.label} #${inc.id}',
                      style: context.text.labelMedium?.copyWith(
                        color: inc.type.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IncidentStatusPill(status: inc.status),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            inc.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium,
          ),
          if (inc.photos.isNotEmpty) ...[
            const SizedBox(height: 10),
            _PhotoThumbs(photos: inc.photos),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: context.palette.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Meta(
                    icon: Icons.place_rounded,
                    text: inc.place,
                    style: muted,
                  ),
                ),
                const SizedBox(width: 10),
                _Meta(
                  icon: Icons.event_rounded,
                  text: relativeDate(inc.date),
                  style: muted,
                ),
                if (item.clientName != null) ...[
                  const SizedBox(width: 10),
                  _Meta(
                    icon: Icons.person_rounded,
                    text: item.clientName!,
                    style: muted.copyWith(fontWeight: FontWeight.w600),
                    maxWidth: 110,
                  ),
                ],
              ],
            ),
          ),
        ],
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
    final shown = photos.take(3).toList();
    final extra = photos.length - shown.length;
    return Row(
      children: [
        for (final p in shown)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: CarImage(fileName: p, width: 46, height: 46),
            ),
          ),
        if (extra > 0)
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.palette.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text('+$extra', style: context.text.labelLarge),
          ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  final TextStyle style;
  final double maxWidth;
  const _Meta({
    required this.icon,
    required this.text,
    required this.style,
    this.maxWidth = 160,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 14, color: context.palette.muted),
      const SizedBox(width: 4),
      Flexible(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Text(
            text,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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
  Widget build(BuildContext context) => EmptyState(
    icon: filtered ? Icons.search_off_rounded : status.icon,
    title: filtered
        ? 'Aucun résultat'
        : 'Aucun incident ${status.label.toLowerCase()}',
    message: filtered
        ? 'Essayez un autre mot-clé ou un autre type.'
        : status == IncidentStatus.resolu
        ? 'Les incidents résolus apparaîtront ici.'
        : 'Tout roule ! Appuyez sur « Déclarer » pour signaler un problème.',
  );
}
