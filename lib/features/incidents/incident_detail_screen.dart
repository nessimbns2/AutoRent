import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'package:latlong2/latlong.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/constants/strings.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/enums.dart';
import '../../models/incident.dart';
import '../../models/incident_stats.dart';
import '../../models/vehicle.dart';
import '../../repositories/incident_repository.dart';
import '../../repositories/vehicle_repository.dart';
import 'location/incident_map.dart';
import 'incident_permissions.dart';
import 'location/location_picker_screen.dart';
import 'widgets/incident_sheets.dart';
import 'widgets/incident_ui.dart';

class IncidentDetailScreen extends StatefulWidget {
  final int incidentId;
  const IncidentDetailScreen({super.key, required this.incidentId});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  final _incidentRepo = IncidentRepository();
  final _vehicleRepo = VehicleRepository();

  IncidentView? _view;
  Vehicle? _vehicle;
  List<IncidentHistoryEntry> _history = const [];
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  bool _didChange = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final view = await _incidentRepo.getViewById(widget.incidentId);
      final v = view == null
          ? null
          : await _vehicleRepo.getById(view.incident.vehicleId);
      final history = view == null
          ? const <IncidentHistoryEntry>[]
          : await _incidentRepo.getHistory(widget.incidentId);
      if (!mounted) return;
      setState(() {
        _view = view;
        _vehicle = v;
        _history = history;
        _error = view == null ? 'Incident introuvable' : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _edit(Incident inc) async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.incidentForm,
      arguments: IncidentFormArgs(
        incidentId: inc.id,
        vehicleId: inc.vehicleId,
        rentalId: inc.rentalId,
      ),
    );
    if (saved == true && mounted) {
      _didChange = true;
      _load();
    }
  }

  Future<void> _delete(Incident inc) async {
    if (!await confirmDeleteIncident(context, inc) || !mounted) return;

    setState(() => _busy = true);
    try {
      await _incidentRepo.delete(inc.id!);
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, e.message);
      }
      return;
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Erreur lors de la suppression : $e');
      }
      return;
    }
    if (!mounted) return;
    showSnack(context, Strings.incidentDeleted);
    Navigator.pop(context, true);
  }

  Future<void> _pickStatus(Incident inc) async {
    if (_busy) return;
    final s = await showStatusPickerSheet(context, inc.status);
    if (s != null && s != inc.status && mounted) await _changeStatus(inc, s);
  }

  Future<void> _changeStatus(Incident inc, IncidentStatus newStatus) async {
    setState(() => _busy = true);
    try {
      await _incidentRepo.changeStatus(
        inc.id!,
        newStatus,
        byUserId: SessionManager.instance.currentUser?.id,
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Erreur lors du changement de statut : $e');
      }
      return;
    }
    if (!mounted) return;
    _didChange = true;
    // Update in place so the timeline animates to the new step.
    setState(() {
      _busy = false;
      _view = IncidentView(
        incident: inc.copyWith(status: newStatus),
        vehicleLabel: _view!.vehicleLabel,
        reporterName: _view!.reporterName,
        clientName: _view!.clientName,
      );
    });
    showSnack(context, 'Statut : ${newStatus.label}');
    // Refresh the history so the new entry (who / when) appears.
    final history = await _incidentRepo.getHistory(inc.id!);
    if (mounted) setState(() => _history = history);
  }

  void _openPhotoViewer(List<String> photos, int index) {
    Navigator.pushNamed(
      context,
      Routes.photoViewer,
      arguments: PhotoViewerArgs(fileNames: photos, initialIndex: index),
    );
  }

  @override
  Widget build(BuildContext context) {
    // System back (Android button / gesture) must also report changes so the
    // list refreshes, not only the AppBar arrow.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _didChange);
      },
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());
    if (_view == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Détail de l'incident")),
        body: ErrorView(
          error: _error ?? 'Incident introuvable',
          onRetry: () {
            setState(() => _loading = true);
            _load();
          },
        ),
      );
    }

    final view = _view!;
    final inc = view.incident;
    var section = 0;
    Widget animated(Widget child) => EntranceAnimation(
      delay: Duration(milliseconds: 120 + 70 * section++),
      child: child,
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context, _didChange),
        ),
        title: Text('${inc.type.label} #${inc.id}'),
        actions: [
          DetailMenu(
            items: [
              if (IncidentPermissions.canEdit)
                DetailMenuItem('Modifier', Icons.edit_rounded, () {
                  if (!_busy) _edit(inc);
                }),
              if (IncidentPermissions.canChangeStatus)
                DetailMenuItem(
                  'Changer le statut',
                  Icons.swap_horiz_rounded,
                  () {
                    if (!_busy) _pickStatus(inc);
                  },
                ),
              if (IncidentPermissions.canDelete)
                DetailMenuItem('Supprimer', Icons.delete_outline_rounded, () {
                  if (!_busy) _delete(inc);
                }, destructive: true),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      bottomNavigationBar: IncidentPermissions.canChangeStatus
          ? _buildActionBar(inc)
          : null,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ResponsiveCenter(
              maxWidth: 850,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    EntranceAnimation(child: _buildHero(view)),
                    animated(
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _pickStatus(inc),
                        child: IncidentSection(
                          icon: Icons.timeline_rounded,
                          title: 'Prise en charge',
                          trailing: TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: _busy ? null : () => _pickStatus(inc),
                            icon: const Icon(
                              Icons.swap_horiz_rounded,
                              size: 18,
                            ),
                            label: const Text('Changer'),
                          ),
                          child: IncidentStatusTimeline(status: inc.status),
                        ),
                      ),
                    ),
                    animated(
                      IncidentSection(
                        icon: Icons.info_outline_rounded,
                        title: 'Informations',
                        child: Column(
                          children: [
                            IncidentInfoTile(
                              icon: Icons.event_rounded,
                              label: "Date de l'incident",
                              value: formatDate(inc.date),
                              color: inc.type.color,
                            ),
                            IncidentInfoTile(
                              icon: Icons.place_rounded,
                              label: 'Lieu',
                              value: inc.place,
                              color: inc.type.color,
                            ),
                            if (inc.hasPosition)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                                child: IncidentMapPreview(
                                  point: LatLng(inc.latitude!, inc.longitude!),
                                  pinColor: inc.type.color,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => LocationPickerScreen(
                                        initial: LatLng(
                                          inc.latitude!,
                                          inc.longitude!,
                                        ),
                                        initialAddress: inc.place,
                                        readOnly: true,
                                        title:
                                            '${inc.type.label} #${inc.id} — lieu',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            IncidentInfoTile(
                              icon: Icons.person_rounded,
                              label: 'Déclaré par',
                              value: view.reporterName ?? '—',
                            ),
                            IncidentInfoTile(
                              icon: Icons.schedule_rounded,
                              label: 'Enregistré le',
                              value: formatDate(inc.createdAt),
                            ),
                          ],
                        ),
                      ),
                    ),
                    animated(
                      IncidentSection(
                        icon: Icons.directions_car_rounded,
                        title: 'Véhicule & location',
                        child: Column(
                          children: [
                            _VehicleTile(
                              vehicle: _vehicle,
                              label: view.vehicleLabel,
                              onTap: _vehicle == null
                                  ? null
                                  : () => Navigator.pushNamed(
                                      context,
                                      Routes.vehicleDetail,
                                      arguments: IdArgs(_vehicle!.id!),
                                    ),
                            ),
                            const Divider(height: 20),
                            if (inc.rentalId != null)
                              IncidentInfoTile(
                                icon: Icons.description_rounded,
                                label: 'Contrat de location #${inc.rentalId}',
                                value: view.clientName != null
                                    ? 'Locataire : ${view.clientName}'
                                    : 'Location liée',
                                color: AppColors.info,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  Routes.rentalDetail,
                                  arguments: IdArgs(inc.rentalId!),
                                ),
                              )
                            else
                              IncidentInfoTile(
                                icon: Icons.link_off_rounded,
                                label: 'Location liée',
                                value: 'Aucune location active à cette date',
                                color: context.palette.muted,
                              ),
                          ],
                        ),
                      ),
                    ),
                    animated(
                      IncidentSection(
                        icon: Icons.notes_rounded,
                        title: 'Description',
                        child: Text(
                          inc.description,
                          style: const TextStyle(fontSize: 15, height: 1.45),
                        ),
                      ),
                    ),
                    animated(
                      IncidentSection(
                        icon: Icons.photo_camera_rounded,
                        title: 'Photos de constat',
                        trailing: Text(
                          '${inc.photos.length}/5',
                          style: TextStyle(color: context.palette.muted),
                        ),
                        child: inc.photos.isEmpty
                            ? Text(
                                'Aucune photo jointe.',
                                style: TextStyle(
                                  color: context.palette.muted,
                                ),
                              )
                            : _PhotoGrid(
                                photos: inc.photos,
                                onTap: (i) => _openPhotoViewer(inc.photos, i),
                              ),
                      ),
                    ),
                    animated(
                      IncidentSection(
                        icon: Icons.history_rounded,
                        title: 'Historique',
                        trailing: Text(
                          '${_history.length} étape${_history.length > 1 ? 's' : ''}',
                          style: TextStyle(color: context.palette.muted),
                        ),
                        child: _HistoryList(entries: _history),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Premium summary card on the app's navy hero gradient (same as the
  /// dashboard header): type badge, status, date and the vehicle.
  Widget _buildHero(IncidentView view) {
    final inc = view.incident;
    final white70 = Colors.white.withValues(alpha: 0.7);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Stack(
          children: [
            // Soft glow in the type colour + large faded icon.
            Positioned(
              right: -60,
              top: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      inc.type.color.withValues(alpha: 0.45),
                      inc.type.color.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -14,
              bottom: -26,
              child: Icon(
                inc.type.icon,
                size: 130,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Hero(
                        tag: incidentHeroTag(inc.id!),
                        child: IncidentTypeBadge(
                          type: inc.type,
                          size: 58,
                          filled: true,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${inc.type.label} #${inc.id}',
                              style: context.text.headlineSmall?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              inc.type.hint,
                              style: context.text.bodySmall?.copyWith(
                                color: white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => _pickStatus(inc),
                        child: IncidentStatusPill(
                          status: inc.status,
                          solid: true,
                        ),
                      ),
                      _HeroTag(
                        icon: Icons.event_rounded,
                        label:
                            '${formatDate(inc.date)} · ${relativeDate(inc.date)}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: CarImage(
                            fileName: _vehicle?.photos.isNotEmpty == true
                                ? _vehicle!.photos.first
                                : null,
                            seed: inc.vehicleId,
                            width: 56,
                            height: 42,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                view.vehicleLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.titleSmall?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                view.clientName != null
                                    ? 'Locataire : ${view.clientName}'
                                    : 'Aucune location liée',
                                style: context.text.bodySmall?.copyWith(
                                  color: white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar(Incident inc) {
    final next = inc.status.next;
    return BottomActionBar(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(a),
            child: child,
          ),
        ),
        child: next == null
            ? SizedBox(
                key: const ValueKey('reopen'),
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _changeStatus(inc, IncidentStatus.enAttente),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text("Rouvrir l'incident"),
                ),
              )
            : PrimaryButton(
                key: ValueKey(next),
                loading: _busy,
                icon: next.icon,
                color: next == IncidentStatus.resolu ? AppColors.success : null,
                label: next == IncidentStatus.enCours
                    ? 'Prendre en charge'
                    : 'Marquer comme résolu',
                onPressed: () => _changeStatus(inc, next),
              ),
      ),
    );
  }
}

/// Small translucent label on the hero card.
class _HeroTag extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeroTag({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.white70),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

/// Vertical timeline of status changes: who did what, and when.
class _HistoryList extends StatelessWidget {
  final List<IncidentHistoryEntry> entries;
  const _HistoryList({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text(
        'Aucun historique.',
        style: TextStyle(color: context.palette.muted),
      );
    }
    // Newest first.
    final list = entries.reversed.toList();
    return Column(
      children: [
        for (final (i, e) in list.indexed)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 34,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: i == 0
                              ? e.toStatus.color
                              : e.toStatus.color.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          e.isDeclaration
                              ? Icons.add_alert_rounded
                              : e.toStatus.icon,
                          size: 16,
                          color: i == 0 ? Colors.white : e.toStatus.color,
                        ),
                      ),
                      if (i < list.length - 1)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: context.palette.border,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: 4,
                      bottom: i < list.length - 1 ? 16 : 0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.isDeclaration
                              ? 'Incident déclaré (${e.toStatus.label.toLowerCase()})'
                              : '${e.fromStatus!.label} → ${e.toStatus.label}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${e.userName ?? 'Utilisateur supprimé'} · '
                          '${formatDate(e.changedAt)} à ${_hhmm(e.changedAt)}',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: context.palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  static String _hhmm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

class _VehicleTile extends StatelessWidget {
  final Vehicle? vehicle;
  final String label;
  final VoidCallback? onTap;
  const _VehicleTile({required this.vehicle, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CarImage(
              fileName: vehicle != null && vehicle!.photos.isNotEmpty
                  ? vehicle!.photos.first
                  : null,
              width: 72,
              height: 56,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Véhicule concerné',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.palette.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: context.palette.muted),
        ],
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  final List<String> photos;
  final void Function(int index) onTap;
  const _PhotoGrid({required this.photos, required this.onTap});

  @override
  Widget build(BuildContext context) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: photos.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ),
    itemBuilder: (context, i) => EntranceAnimation(
      delay: EntranceAnimation.staggerDelay(i),
      offsetY: 12,
      child: Material(
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => onTap(i),
          child: CarImage(fileName: photos[i]),
        ),
      ),
    ),
  );
}
