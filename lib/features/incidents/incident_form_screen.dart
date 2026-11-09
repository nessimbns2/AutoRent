import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/strings.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/enums.dart';
import '../../models/incident.dart';
import '../../models/rental.dart';
import '../../models/vehicle.dart';
import '../../repositories/incident_repository.dart';
import '../../repositories/rental_repository.dart';
import '../../repositories/vehicle_repository.dart';

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
  Rental? _activeRental;
  Incident? _existing;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.incidentId != null;

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.vehicleId;
    _linkedRentalId = widget.rentalId;
    _dateController.text = formatDate(_date);
    _load();
  }

  Future<void> _load() async {
    _vehicles = await _vehicleRepo.getAll();
    if (_isEdit) {
      _existing = await _incidentRepo.getById(widget.incidentId!);
      if (_existing != null) {
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
    }
    await _checkActiveRental();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _checkActiveRental() async {
    if (_linkedRentalId != null) {
      final r = await _rentalRepo.getById(_linkedRentalId!);
      if (mounted) setState(() => _activeRental = r);
      return;
    }
    if (_selectedVehicleId != null) {
      final r =
          await _rentalRepo.getActiveForVehicle(_selectedVehicleId!, _date);
      if (mounted) {
        setState(() {
          _activeRental = r;
          _linkedRentalId = r?.id;
        });
      }
    } else if (mounted) {
      setState(() {
        _activeRental = null;
        _linkedRentalId = null;
      });
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _placeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: "Date de l'incident",
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateController.text = formatDate(picked);
      });
      await _checkActiveRental();
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicleId == null) {
      showSnack(context, 'Veuillez sélectionner un véhicule');
      return;
    }
    setState(() => _saving = true);
    try {
      final incident = Incident(
        id: _existing?.id,
        vehicleId: _selectedVehicleId!,
        rentalId: _linkedRentalId,
        reportedByUserId: _existing?.reportedByUserId ??
            SessionManager.instance.currentUser?.id,
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
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());
    final lockVehicle = widget.vehicleId != null && !_isEdit;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? "Modifier l'incident" : 'Déclarer un incident'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            // Type selector ---------------------------------------------------
            Row(children: [
              for (final t in IncidentType.values) ...[
                if (t != IncidentType.values.first) const SizedBox(width: 12),
                Expanded(
                  child: _TypeCard(
                    type: t,
                    selected: _type == t,
                    onTap: () => setState(() => _type = t),
                  ),
                ),
              ],
            ]),
            const SizedBox(height: 14),
            FormSection(
              title: 'Véhicule',
              icon: Icons.directions_car_rounded,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _selectedVehicleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Véhicule concerné',
                    prefixIcon: Icon(Icons.directions_car_outlined),
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
                          await _checkActiveRental();
                        },
                  validator: (v) =>
                      v == null ? 'Choisissez un véhicule' : null,
                ),
                InfoBanner(
                  icon: _activeRental != null
                      ? Icons.link_rounded
                      : Icons.link_off_rounded,
                  color: _activeRental != null
                      ? AppColors.info
                      : context.palette.muted,
                  text: _activeRental != null
                      ? 'Rattaché à la location #${_activeRental!.id} '
                          '(du ${formatDayMonth(_activeRental!.startDate)} au ${formatDayMonth(_activeRental!.endDate)})'
                      : 'Aucune location en cours détectée à cette date.',
                ),
              ],
            ),
            FormSection(
              title: 'Circonstances',
              icon: Icons.description_rounded,
              color: AppColors.info,
              children: [
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Date de l'incident",
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  onTap: _pickDate,
                  validator: (v) => Validators.required(v, 'La date'),
                ),
                TextFormField(
                  controller: _placeController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Lieu',
                    hintText: 'Ville, route, repère…',
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                  validator: (v) => Validators.required(v, 'Le lieu'),
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Description des faits',
                    hintText: 'Décrivez ce qui s\'est passé (10 caractères min.)',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Veuillez saisir une description détaillée (au moins 10 caractères)'
                      : null,
                ),
              ],
            ),
            FormSection(
              title: 'Photos de constat',
              icon: Icons.photo_camera_rounded,
              color: AppColors.violet,
              children: [
                PhotoPickerField(
                  fileNames: _photos,
                  maxPhotos: 5,
                  onChanged: (list) => setState(() => _photos = list),
                ),
              ],
            ),
            if (_isEdit)
              FormSection(
                title: 'Statut',
                icon: Icons.flag_rounded,
                color: AppColors.warning,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in IncidentStatus.values)
                      ChoiceChip(
                        label: Text(s.label),
                        selected: _status == s,
                        showCheckmark: false,
                        selectedColor:
                            incidentStatusColor(s).withValues(alpha: 0.15),
                        labelStyle: context.text.labelMedium?.copyWith(
                            color:
                                _status == s ? incidentStatusColor(s) : null),
                        onSelected: (_) => setState(() => _status = s),
                      ),
                  ]),
                ],
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: _isEdit ? 'Enregistrer' : 'Envoyer la déclaration',
          icon: Icons.send_rounded,
          color: _isEdit ? null : incidentTypeColor(_type),
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}

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
    final color = incidentTypeColor(type);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color : context.colors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
              color: selected ? color : context.palette.border, width: 1.4),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6))
                ]
              : null,
        ),
        child: Column(children: [
          Icon(incidentTypeIcon(type),
              size: 30, color: selected ? Colors.white : color),
          const SizedBox(height: 6),
          Text(type.label,
              style: context.text.titleSmall
                  ?.copyWith(color: selected ? Colors.white : null)),
        ]),
      ),
    );
  }
}
