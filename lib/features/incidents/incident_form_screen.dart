import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/enums.dart';
import '../../models/incident.dart';
import '../../models/rental.dart';
import '../../models/vehicle.dart';
import '../../repositories/incident_repository.dart';
import '../../repositories/rental_repository.dart';
import '../../repositories/vehicle_repository.dart';
import 'widgets/incident_ui.dart';

class IncidentFormScreen extends StatefulWidget {
  final int? incidentId;
  final int? vehicleId;
  final int? rentalId;

  const IncidentFormScreen({
    super.key,
    this.incidentId,
    this.vehicleId,
    this.rentalId,
  });

  @override
  State<IncidentFormScreen> createState() => _IncidentFormScreenState();
}

class _IncidentFormScreenState extends State<IncidentFormScreen> {
  static const _minDescription = 10;
  static const _maxPhotos = 5;

  final _formKey = GlobalKey<FormState>();
  final _incidentRepo = IncidentRepository();
  final _vehicleRepo = VehicleRepository();
  final _rentalRepo = RentalRepository();

  IncidentType _type = IncidentType.panne;
  int? _selectedVehicleId;
  int? _linkedRentalId;
  DateTime _date = DateTime.now();
  final _dateController = TextEditingController();
  final _placeController = TextEditingController();
  final _descriptionController = TextEditingController();
  IncidentStatus _status = IncidentStatus.enAttente;
  List<String> _photos = [];

  List<Vehicle> _vehicles = [];
  RentalView? _activeRental;
  Incident? _existing;
  bool _loading = true;
  bool _saving = false;
  bool _lookingUpRental = false;
  Object? _loadError;

  /// Incremented on every rental lookup so a slow, outdated lookup can't
  /// overwrite the result of a newer one.
  int _lookupToken = 0;

  bool get _isEdit => widget.incidentId != null;

  /// Declared from a rental's detail screen: that rental always wins.
  bool get _rentalPinned => widget.rentalId != null && !_isEdit;

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.vehicleId;
    _linkedRentalId = widget.rentalId;
    _dateController.text = formatDate(_date);
    _descriptionController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _placeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _vehicles = await _vehicleRepo.getAll();
      if (_isEdit) {
        _existing = await _incidentRepo.getById(widget.incidentId!);
        if (_existing == null) {
          throw const AppException('Incident introuvable');
        }
        _type = _existing!.type;
        _selectedVehicleId = _existing!.vehicleId;
        _linkedRentalId = _existing!.rentalId;
        _date = _existing!.date;
        _dateController.text = formatDate(_date);
        _placeController.text = _existing!.place;
        _descriptionController.text = _existing!.description;
        _status = _existing!.status;
        _photos = List<String>.from(_existing!.photos);
      }
      // Keep the stored / prefilled link as is when opening the form; only
      // look up an active rental for a brand-new declaration.
      if (_linkedRentalId != null) {
        _activeRental = await _rentalRepo.getViewById(_linkedRentalId!);
      } else {
        await _lookUpActiveRental();
      }
    } catch (e) {
      _loadError = e;
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Re-links the incident to the rental that is in progress for the selected
  /// vehicle on the selected date. Called whenever vehicle or date changes.
  Future<void> _lookUpActiveRental() async {
    if (_rentalPinned) return;
    final token = ++_lookupToken;
    final vehicleId = _selectedVehicleId;
    if (mounted) setState(() => _lookingUpRental = true);
    RentalView? view;
    try {
      if (vehicleId != null) {
        final r = await _rentalRepo.getActiveForVehicle(vehicleId, _date);
        if (r != null) view = await _rentalRepo.getViewById(r.id!);
      }
    } finally {
      if (mounted && token == _lookupToken) {
        setState(() {
          _activeRental = view;
          _linkedRentalId = view?.rental.id;
          _lookingUpRental = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(2020),
      lastDate: now,
      helpText: "Date de l'incident",
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateController.text = formatDate(picked);
      });
      await _lookUpActiveRental();
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      showSnack(context, 'Veuillez corriger les champs en rouge');
      return;
    }
    setState(() => _saving = true);

    try {
      final currentUserId = SessionManager.instance.currentUser?.id;
      final incident = Incident(
        id: _existing?.id,
        vehicleId: _selectedVehicleId!,
        rentalId: _linkedRentalId,
        reportedByUserId: _existing?.reportedByUserId ?? currentUserId,
        type: _type,
        date: _date,
        place: _placeController.text.trim(),
        description: _descriptionController.text.trim(),
        status: _status,
        photos: _photos,
        createdAt: _existing?.createdAt ?? DateTime.now(),
      );

      if (_isEdit) {
        await _incidentRepo.update(incident);
        if (!mounted) return;
        showSnack(context, Strings.incidentUpdated);
      } else {
        await _incidentRepo.insert(incident);
        if (!mounted) return;
        showSnack(context, Strings.incidentAdded);
      }
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    } catch (e) {
      if (mounted) showSnack(context, "Erreur lors de l'enregistrement : $e");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Incident')),
        body: ErrorView(
          error: _loadError is AppException
              ? (_loadError as AppException).message
              : _loadError!,
          onRetry: () {
            setState(() {
              _loading = true;
              _loadError = null;
            });
            _load();
          },
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    var section = 0;
    Widget animated(Widget child) => EntranceAnimation(
          delay: Duration(milliseconds: 60 * section++),
          child: child,
        );

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(_isEdit ? "Modifier l'incident" : 'Déclarer un incident'),
        backgroundColor: _type.color,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBar: _buildSaveBar(),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 750,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                // 1. Type
                animated(Row(
                  children: [
                    for (final t in [IncidentType.panne, IncidentType.accident]) ...[
                      Expanded(
                        child: _TypeCard(
                          type: t,
                          selected: _type == t,
                          onTap: () => setState(() => _type = t),
                        ),
                      ),
                      if (t == IncidentType.panne) const SizedBox(width: 12),
                    ],
                  ],
                )),
                const SizedBox(height: 16),

                // 2. Véhicule + location liée
                animated(IncidentSection(
                  icon: Icons.directions_car_rounded,
                  title: 'Véhicule concerné',
                  child: Column(
                    children: [
                      _buildVehicleField(),
                      const SizedBox(height: 12),
                      _buildRentalBanner(),
                    ],
                  ),
                )),

                // 3. Quand & où
                animated(IncidentSection(
                  icon: Icons.place_rounded,
                  title: 'Quand et où ?',
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: "Date de l'incident",
                          prefixIcon: Icon(Icons.event_rounded),
                          suffixIcon: Icon(Icons.edit_calendar_rounded),
                        ),
                        onTap: _pickDate,
                        validator: (v) => Validators.required(v, 'La date'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _placeController,
                        decoration: const InputDecoration(
                          labelText: 'Lieu',
                          hintText: 'Ville, route, repère…',
                          prefixIcon: Icon(Icons.location_on_outlined),
                        ),
                        validator: (v) => Validators.required(v, 'Le lieu'),
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ],
                  ),
                )),

                // 4. Description
                animated(IncidentSection(
                  icon: Icons.notes_rounded,
                  title: 'Que s\'est-il passé ?',
                  trailing: _DescriptionCounter(
                    length: _descriptionController.text.trim().length,
                    min: _minDescription,
                  ),
                  child: TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    minLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: _type == IncidentType.accident
                          ? 'Ex : choc arrière à un feu rouge, pare-choc enfoncé…'
                          : 'Ex : voyant moteur allumé, le véhicule ne démarre plus…',
                      alignLabelWithHint: true,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().length < _minDescription) {
                        return 'Décrivez le problème (au moins $_minDescription caractères)';
                      }
                      return null;
                    },
                  ),
                )),

                // 5. Photos
                animated(IncidentSection(
                  icon: Icons.photo_camera_rounded,
                  title: 'Photos de constat',
                  trailing: Text(
                    '${_photos.length}/$_maxPhotos',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                  child: PhotoPickerField(
                    fileNames: _photos,
                    maxPhotos: _maxPhotos,
                    onChanged: (list) => setState(() => _photos = list),
                  ),
                )),

                // 6. Statut (edit only — a new declaration starts "en attente")
                if (_isEdit)
                  animated(IncidentSection(
                    icon: Icons.flag_rounded,
                    title: 'Statut',
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in IncidentStatus.values)
                          ChoiceChip(
                            avatar: Icon(s.icon,
                                size: 18,
                                color: _status == s ? Colors.white : s.color),
                            label: Text(s.label),
                            selected: _status == s,
                            showCheckmark: false,
                            selectedColor: s.color,
                            labelStyle: TextStyle(
                              color: _status == s ? Colors.white : null,
                              fontWeight: FontWeight.w600,
                            ),
                            shape: const StadiumBorder(),
                            onSelected: (_) => setState(() => _status = s),
                          ),
                      ],
                    ),
                  )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleField() {
    final lockVehicle = widget.vehicleId != null && !_isEdit;
    return DropdownButtonFormField<int>(
      initialValue: _selectedVehicleId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Véhicule',
        prefixIcon: const Icon(Icons.directions_car_outlined),
        suffixIcon: lockVehicle ? const Icon(Icons.lock_outline) : null,
      ),
      items: [
        for (final v in _vehicles)
          DropdownMenuItem(
            value: v.id,
            child: Text(v.label, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: lockVehicle
          ? null
          : (id) async {
              setState(() => _selectedVehicleId = id);
              await _lookUpActiveRental();
            },
      validator: (v) => v == null ? 'Choisissez un véhicule' : null,
    );
  }

  Widget _buildRentalBanner() {
    final scheme = Theme.of(context).colorScheme;
    final linked = _activeRental != null;
    final color = linked ? Colors.indigo : scheme.outline;

    final Widget content;
    if (_lookingUpRental) {
      content = Row(
        key: const ValueKey('loading'),
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('Recherche d\'une location active…',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      );
    } else if (linked) {
      final r = _activeRental!;
      content = Row(
        key: ValueKey('rental-${r.rental.id}'),
        children: [
          Icon(Icons.link_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rattaché à la location #${r.rental.id}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, color: color)),
                const SizedBox(height: 2),
                Text(
                  '${r.clientName} · ${formatDate(r.rental.startDate)} → ${formatDate(r.rental.endDate)}',
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      content = Row(
        key: const ValueKey('none'),
        children: [
          Icon(Icons.link_off_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _selectedVehicleId == null
                  ? 'Choisissez un véhicule pour retrouver sa location en cours'
                  : 'Aucune location active pour ce véhicule à cette date',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: content,
        ),
      ),
    );
  }

  Widget _buildSaveBar() => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: _type.gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _type.color.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              onPressed: _saving ? null : _save,
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _saving
                    ? const SizedBox(
                        key: ValueKey('saving'),
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        _isEdit ? Icons.save_rounded : Icons.send_rounded,
                        key: const ValueKey('idle'),
                        color: Colors.white,
                      ),
              ),
              label: Text(
                _isEdit ? 'Enregistrer les modifications' : "Déclarer l'incident",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Big selectable card for Accident / Panne
// ─────────────────────────────────────────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final IncidentType type;
  final bool selected;
  final VoidCallback onTap;
  const _TypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedScale(
      scale: selected ? 1.0 : 0.95,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: selected ? type.gradient : null,
          color: selected ? null : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : scheme.outlineVariant,
            width: 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: type.color.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              child: Column(
                children: [
                  AnimatedRotation(
                    turns: selected ? 0 : -0.03,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      type.icon,
                      size: 40,
                      color: selected ? Colors.white : type.color,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    type.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: selected ? Colors.white : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type.hint,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: selected
                          ? Colors.white.withValues(alpha: 0.9)
                          : scheme.onSurfaceVariant,
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

class _DescriptionCounter extends StatelessWidget {
  final int length;
  final int min;
  const _DescriptionCounter({required this.length, required this.min});

  @override
  Widget build(BuildContext context) {
    final ok = length >= min;
    final color = ok ? const Color(0xFF10B981) : Theme.of(context).colorScheme.outline;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: Row(
        key: ValueKey(ok),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.edit_note_rounded,
              size: 16, color: color),
          const SizedBox(width: 4),
          Text(ok ? '$length car.' : '$length/$min',
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
