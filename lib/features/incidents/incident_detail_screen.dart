import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/constants/strings.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/enums.dart';
import '../../models/incident.dart';
import '../../models/vehicle.dart';
import '../../repositories/incident_repository.dart';
import '../../repositories/vehicle_repository.dart';
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
      if (!mounted) return;
      setState(() {
        _view = view;
        _vehicle = v;
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
    final ok = await confirmDialog(
      context,
      title: "Supprimer l'incident",
      message:
          'Voulez-vous vraiment supprimer définitivement cet incident et ses photos ?',
      confirmLabel: 'Supprimer',
    );
    if (ok != true || !mounted) return;

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

  Future<void> _changeStatus(Incident inc, IncidentStatus newStatus) async {
    setState(() => _busy = true);
    try {
      await _incidentRepo.changeStatus(inc.id!, newStatus);
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
    final scheme = Theme.of(context).colorScheme;
    var section = 0;
    Widget animated(Widget child) => EntranceAnimation(
          delay: Duration(milliseconds: 120 + 70 * section++),
          child: child,
        );

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      bottomNavigationBar: _buildActionBar(inc),
      body: CustomScrollView(
        slivers: [
          _buildHeader(inc),
          SliverToBoxAdapter(
            child: ResponsiveCenter(
              maxWidth: 850,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    animated(IncidentSection(
                      icon: Icons.timeline_rounded,
                      title: 'Suivi de la prise en charge',
                      child: IncidentStatusTimeline(status: inc.status),
                    )),
                    animated(IncidentSection(
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
                          IncidentInfoTile(
                            icon: Icons.badge_rounded,
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
                    )),
                    animated(IncidentSection(
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
                              icon: Icons.assignment_rounded,
                              label: 'Contrat de location #${inc.rentalId}',
                              value: view.clientName != null
                                  ? 'Locataire : ${view.clientName}'
                                  : 'Location liée',
                              color: Colors.indigo,
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
                              color: scheme.outline,
                            ),
                        ],
                      ),
                    )),
                    animated(IncidentSection(
                      icon: Icons.notes_rounded,
                      title: 'Description',
                      child: Text(
                        inc.description,
                        style: const TextStyle(fontSize: 15, height: 1.45),
                      ),
                    )),
                    animated(IncidentSection(
                      icon: Icons.photo_library_rounded,
                      title: 'Photos de constat',
                      trailing: Text('${inc.photos.length}/5',
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                      child: inc.photos.isEmpty
                          ? Text('Aucune photo jointe.',
                              style:
                                  TextStyle(color: scheme.onSurfaceVariant))
                          : _PhotoGrid(
                              photos: inc.photos,
                              onTap: (i) => _openPhotoViewer(inc.photos, i),
                            ),
                    )),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildHeader(Incident inc) => SliverAppBar(
        pinned: true,
        expandedHeight: 210,
        backgroundColor: inc.type.color,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context, _didChange),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            tooltip: 'Modifier',
            onPressed: _busy ? null : () => _edit(inc),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Supprimer',
            onPressed: _busy ? null : () => _delete(inc),
          ),
        ],
        flexibleSpace: FlexibleSpaceBar(
          titlePadding: const EdgeInsetsDirectional.only(start: 56, bottom: 14),
          title: Text(
            '${inc.type.label} #${inc.id}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          background: Container(
            decoration: BoxDecoration(gradient: inc.type.gradient),
            child: Stack(
              children: [
                // Large faded icon as decoration
                Positioned(
                  right: -20,
                  bottom: -24,
                  child: Icon(inc.type.icon,
                      size: 180, color: Colors.white.withValues(alpha: 0.12)),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 56),
                    child: Row(
                      children: [
                        Hero(
                          tag: incidentHeroTag(inc.id!),
                          child: IncidentTypeBadge(
                              type: inc.type, size: 64, onDark: true),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: IncidentStatusPill(
                                  key: ValueKey(inc.status),
                                  status: inc.status,
                                  onDark: true,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                inc.type.hint,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
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
      );

  Widget _buildActionBar(Incident inc) {
    final next = inc.status.next;
    return SafeArea(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: next == null
            ? Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _busy
                      ? null
                      : () => _changeStatus(inc, IncidentStatus.enAttente),
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Rouvrir l\'incident'),
                ),
              )
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                        scale: Tween(begin: 0.9, end: 1.0).animate(a),
                        child: child),
                  ),
                  child: FilledButton.icon(
                    key: ValueKey(next),
                    style: FilledButton.styleFrom(
                      backgroundColor: next.color,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    onPressed: _busy ? null : () => _changeStatus(inc, next),
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(next.icon),
                    label: Text(next == IncidentStatus.enCours
                        ? 'Prendre en charge'
                        : 'Marquer comme résolu'),
                  ),
                ),
              ),
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  final Vehicle? vehicle;
  final String label;
  final VoidCallback? onTap;
  const _VehicleTile({required this.vehicle, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                Text('Véhicule concerné',
                    style: TextStyle(
                        fontSize: 12, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(label,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: scheme.outline),
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
