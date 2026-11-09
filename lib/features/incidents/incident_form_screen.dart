import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'package:latlong2/latlong.dart';

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
import 'location/incident_map.dart';
import 'incident_permissions.dart';
import 'location/location_picker_screen.dart';
import 'widgets/incident_sheets.dart';
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

  /// Optional position chosen on the map.
  LatLng? _position;

  List<Vehicle> _vehicles = [];
  List<String> _recentPlaces = [];

  /// Snapshot of the form right after loading, to detect unsaved changes.
  String _initialSignature = '';
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
    // Rebuild for the description counter, place suggestions and the
    // unsaved-changes guard.
    _descriptionController.addListener(() => setState(() {}));
    _placeController.addListener(() => setState(() {}));
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
      _recentPlaces = await _incidentRepo.recentPlaces();
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
        if (_existing!.hasPosition) {
          _position = LatLng(_existing!.latitude!, _existing!.longitude!);
        }
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
    _initialSignature = _signature;
    if (mounted) setState(() => _loading = false);
  }

  String get _signature => [
    _type.value,
    _selectedVehicleId,
    toIsoDate(_date),
    _placeController.text.trim(),
    _descriptionController.text.trim(),
    _status.value,
    _photos.join(','),
    _position == null ? '' : formatLatLng(_position!),
  ].join('|');

  Future<void> _pickLocation() async {
    FocusScope.of(context).unfocus();
    final picked = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initial: _position,
          initialAddress: _position == null
              ? null
              : _placeController.text.trim().isEmpty
              ? null
              : _placeController.text.trim(),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _position = picked.point;
      // The pin is the source of truth: "Lieu" follows the picked address.
      final address = picked.address?.trim();
      if (address != null && address.isNotEmpty) {
        _placeController.text = address;
        _placeController.selection = TextSelection.collapsed(
          offset: address.length,
        );
      }
    });
  }

  Widget _buildLocationField() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      alignment: Alignment.topCenter,
      child: _position == null
          ? SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: AppColors.brand,
                  side: BorderSide(
                    color: AppColors.brand.withValues(alpha: 0.5),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _pickLocation,
                icon: const Icon(Icons.map_rounded),
                label: const Text('Indiquer sur la carte'),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IncidentMapPreview(
                  point: _position!,
                  pinColor: _type.color,
                  onTap: _pickLocation,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.gps_fixed_rounded,
                      size: 15,
                      color: context.palette.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        formatLatLng(_position!),
                        style: TextStyle(
                          fontSize: 12.5,
                          color: context.palette.muted,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickLocation,
                      child: const Text('Modifier'),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      onPressed: () => setState(() => _position = null),
                      child: const Text('Retirer'),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  bool get _hasUnsavedChanges => !_loading && _signature != _initialSignature;

  Future<void> _confirmLeave() async {
    final leave = await showIncidentConfirmSheet(
      context,
      icon: Icons.edit_off_rounded,
      color: AppColors.brand,
      title: _isEdit
          ? 'Abandonner les modifications ?'
          : 'Abandonner la déclaration ?',
      message: 'Les informations saisies ne seront pas enregistrées.',
      confirmLabel: 'Abandonner',
      cancelLabel: 'Continuer',
    );
    if (leave && mounted) Navigator.pop(context, false);
  }

  Future<void> _setDate(DateTime d) async {
    setState(() {
      _date = DateTime(d.year, d.month, d.day);
      _dateController.text = formatDate(_date);
    });
    await _lookUpActiveRental();
  }

  Future<void> _pickVehicle() async {
    final v = await showVehiclePickerSheet(
      context,
      vehicles: _vehicles,
      selectedId: _selectedVehicleId,
    );
    if (v == null || !mounted || v.id == _selectedVehicleId) return;
    setState(() => _selectedVehicleId = v.id);
    await _lookUpActiveRental();
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
    if (picked != null) await _setDate(picked);
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
        latitude: _position?.latitude,
        longitude: _position?.longitude,
        createdAt: _existing?.createdAt ?? DateTime.now(),
      );

      if (_isEdit) {
        await _incidentRepo.update(incident, byUserId: currentUserId);
      } else {
        await _incidentRepo.insert(incident);
      }
      if (!mounted) return;
      _initialSignature = _signature; // nothing left unsaved
      await showIncidentSuccessDialog(
        context,
        title: _isEdit ? Strings.incidentUpdated : Strings.incidentAdded,
        message: _isEdit
            ? 'Les modifications ont été enregistrées.'
            : 'La déclaration est en attente de prise en charge.',
        color: _isEdit ? AppColors.success : AppColors.brand,
      );
      if (!mounted) return;
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

    var section = 0;
    Widget animated(Widget child) => EntranceAnimation(
      delay: Duration(milliseconds: 60 * section++),
      child: child,
    );

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEdit ? "Modifier l'incident" : 'Déclarer un incident'),
        ),
        bottomNavigationBar: _buildSaveBar(),
        body: SafeArea(
          child: ResponsiveCenter(
            maxWidth: 750,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  // 1. Type
                  animated(
                    Row(
                      children: [
                        for (final t in [
                          IncidentType.panne,
                          IncidentType.accident,
                        ]) ...[
                          Expanded(
                            child: _TypeCard(
                              type: t,
                              selected: _type == t,
                              onTap: () => setState(() => _type = t),
                            ),
                          ),
                          if (t == IncidentType.panne)
                            const SizedBox(width: 12),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Véhicule + location liée
                  animated(
                    IncidentSection(
                      icon: Icons.directions_car_rounded,
                      iconColor: AppColors.info,
                      title: 'Véhicule concerné',
                      child: Column(
                        children: [
                          _buildVehicleField(),
                          const SizedBox(height: 12),
                          _buildRentalBanner(),
                        ],
                      ),
                    ),
                  ),

                  // 3. Quand & où
                  animated(
                    IncidentSection(
                      icon: Icons.place_rounded,
                      title: 'Quand et où ?',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildDateShortcuts(),
                          ),
                          const SizedBox(height: 12),
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
                          _buildPlaceSuggestions(),
                          const SizedBox(height: 12),
                          _buildLocationField(),
                        ],
                      ),
                    ),
                  ),

                  // 4. Description
                  animated(
                    IncidentSection(
                      icon: Icons.notes_rounded,
                      iconColor: AppColors.violet,
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
                    ),
                  ),

                  // 5. Photos
                  animated(
                    IncidentSection(
                      icon: Icons.photo_camera_rounded,
                      iconColor: AppColors.teal,
                      title: 'Photos de constat',
                      trailing: Text(
                        '${_photos.length}/$_maxPhotos',
                        style: context.text.bodySmall,
                      ),
                      child: PhotoPickerField(
                        fileNames: _photos,
                        maxPhotos: _maxPhotos,
                        onChanged: (list) => setState(() => _photos = list),
                      ),
                    ),
                  ),

                  // 6. Statut (edit only — a new declaration starts "en attente").
                  // Only the admin may change it.
                  if (_isEdit && IncidentPermissions.canChangeStatus)
                    animated(
                      IncidentSection(
                        icon: Icons.flag_rounded,
                        iconColor: AppColors.success,
                        title: 'Statut',
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final s in IncidentStatus.values)
                              ChoiceChip(
                                avatar: Icon(
                                  s.icon,
                                  size: 18,
                                  color: _status == s ? Colors.white : s.color,
                                ),
                                label: Text(s.label),
                                selected: _status == s,
                                showCheckmark: false,
                                selectedColor: s.color,
                                backgroundColor: context.colors.surface,
                                side: BorderSide(
                                  color: _status == s
                                      ? s.color
                                      : context.palette.border,
                                ),
                                labelStyle: TextStyle(
                                  color: _status == s
                                      ? Colors.white
                                      : context.colors.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: const StadiumBorder(),
                                onSelected: (_) => setState(() => _status = s),
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

  Widget _buildVehicleField() {
    final lockVehicle = widget.vehicleId != null && !_isEdit;
    final scheme = Theme.of(context).colorScheme;
    return FormField<int>(
      // Re-validate against the latest selection.
      key: ValueKey('vehicle-$_selectedVehicleId'),
      initialValue: _selectedVehicleId,
      validator: (_) =>
          _selectedVehicleId == null ? 'Choisissez un véhicule' : null,
      builder: (field) {
        Vehicle? v;
        for (final x in _vehicles) {
          if (x.id == _selectedVehicleId) v = x;
        }
        final borderColor = field.hasError
            ? scheme.error
            : v != null
            ? AppColors.brand
            : context.palette.border;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Material(
              color: v != null
                  ? AppColors.brand.withValues(alpha: 0.06)
                  : context.palette.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: lockVehicle ? null : _pickVehicle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: borderColor,
                      width: v != null ? 1.5 : 1,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: Row(
                      key: ValueKey(v?.id),
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: v == null
                              ? Container(
                                  width: 64,
                                  height: 48,
                                  color: context.colors.surface,
                                  child: Icon(
                                    Icons.directions_car_rounded,
                                    color: context.palette.muted,
                                  ),
                                )
                              : CarImage(
                                  fileName: v.photos.isNotEmpty
                                      ? v.photos.first
                                      : null,
                                  width: 64,
                                  height: 48,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: v == null
                              ? Text(
                                  'Choisir un véhicule',
                                  style: context.text.bodyMedium?.copyWith(
                                    color: context.palette.muted,
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${v.brand} ${v.model}',
                                      style: context.text.titleSmall,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(v.plate, style: context.text.bodySmall),
                                  ],
                                ),
                        ),
                        Icon(
                          lockVehicle
                              ? Icons.lock_outline_rounded
                              : Icons.unfold_more_rounded,
                          color: context.palette.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Text(
                  field.errorText!,
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDateShortcuts() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final selected = DateTime(_date.year, _date.month, _date.day);
    // Same look as the app's PillTabs: ink when selected (orange in dark
    // mode), surface with a soft border otherwise.
    final selectedBg = context.isDark ? AppColors.brand : AppColors.ink;
    Widget brownChip({
      required String label,
      required bool isSelected,
      required VoidCallback onTap,
      IconData? icon,
    }) => ChoiceChip(
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : AppColors.brand,
            ),
      label: Text(label),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: selectedBg,
      backgroundColor: context.colors.surface,
      side: BorderSide(
        color: isSelected ? Colors.transparent : context.palette.border,
      ),
      labelStyle: context.text.labelMedium?.copyWith(
        color: isSelected ? Colors.white : context.colors.onSurface,
      ),
      onSelected: (_) => onTap(),
      shape: const StadiumBorder(),
    );
    final isOther = selected != today && selected != yesterday;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        brownChip(
          label: "Aujourd'hui",
          isSelected: selected == today,
          onTap: () => _setDate(today),
        ),
        brownChip(
          label: 'Hier',
          isSelected: selected == yesterday,
          onTap: () => _setDate(yesterday),
        ),
        brownChip(
          label: isOther ? formatDate(_date) : 'Autre date',
          icon: Icons.calendar_month_rounded,
          isSelected: isOther,
          onTap: _pickDate,
        ),
      ],
    );
  }

  Widget _buildPlaceSuggestions() {
    final current = _placeController.text.trim().toLowerCase();
    final suggestions = _recentPlaces
        .where((p) => p.toLowerCase() != current)
        .toList();
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final p in suggestions)
            ActionChip(
              avatar: const Icon(Icons.history_rounded, size: 16),
              label: Text(p),
              shape: const StadiumBorder(),
              onPressed: () => setState(() {
                _placeController.text = p;
                _placeController.selection = TextSelection.collapsed(
                  offset: p.length,
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildRentalBanner() {
    final linked = _activeRental != null;
    final color = linked ? AppColors.info : context.palette.muted;

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
          Text(
            'Recherche d\'une location active…',
            style: TextStyle(color: context.palette.muted),
          ),
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
                Text(
                  'Rattaché à la location #${r.rental.id}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  '${r.clientName} · ${formatDate(r.rental.startDate)} → ${formatDate(r.rental.endDate)}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: context.palette.muted,
                  ),
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
              style: TextStyle(fontSize: 12.5, color: context.palette.muted),
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

  Widget _buildSaveBar() => BottomActionBar(
    child: PrimaryButton(
      loading: _saving,
      icon: _isEdit ? Icons.save_rounded : Icons.send_rounded,
      label: _isEdit ? 'Enregistrer les modifications' : "Déclarer l'incident",
      onPressed: _save,
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
    return AnimatedScale(
      scale: selected ? 1.0 : 0.97,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: selected ? type.color : context.palette.border,
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? type.color.withValues(alpha: 0.22)
                  : context.palette.cardShadow,
              blurRadius: selected ? 18 : 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onTap,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
                  child: Column(
                    children: [
                      AnimatedScale(
                        scale: selected ? 1.08 : 1.0,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack,
                        child: IncidentTypeBadge(
                          type: type,
                          size: 56,
                          filled: selected,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(type.label, style: context.text.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        type.hint,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Check mark on the selected card.
                Positioned(
                  top: 10,
                  right: 10,
                  child: AnimatedScale(
                    scale: selected ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: type.color,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
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

class _DescriptionCounter extends StatelessWidget {
  final int length;
  final int min;
  const _DescriptionCounter({required this.length, required this.min});

  @override
  Widget build(BuildContext context) {
    final ok = length >= min;
    final color = ok
        ? AppColors.success
        : context.palette.muted;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: Row(
        key: ValueKey(ok),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.edit_note_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            ok ? '$length car.' : '$length/$min',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
