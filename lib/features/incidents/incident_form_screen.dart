import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';
import '../../core/session/session_manager.dart';
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
      final r = await _rentalRepo.getActiveForVehicle(_selectedVehicleId!, _date);
      if (mounted) {
        setState(() {
          _activeRental = r;
          _linkedRentalId = r?.id;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _activeRental = null;
          _linkedRentalId = null;
        });
      }
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
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 750,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Type
                Center(
                  child: SegmentedButton<IncidentType>(
                    segments: const [
                      ButtonSegment(
                        value: IncidentType.panne,
                        label: Text('Panne'),
                        icon: Icon(Icons.build_outlined),
                      ),
                      ButtonSegment(
                        value: IncidentType.accident,
                        label: Text('Accident'),
                        icon: Icon(Icons.car_crash_outlined),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (set) =>
                        setState(() => _type = set.first),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Véhicule
                DropdownButtonFormField<int>(
                  initialValue: _selectedVehicleId,
                  decoration: const InputDecoration(labelText: 'Véhicule'),
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
                  validator: (v) => v == null ? 'Choisissez un véhicule' : null,
                ),
                const SizedBox(height: 12),

                // 3. Location liée info banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _activeRental != null
                        ? Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withValues(alpha: 0.3)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _activeRental != null
                          ? Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3)
                          : Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link,
                        size: 20,
                        color: _activeRental != null
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _activeRental != null
                              ? 'Rattaché à la location #${_activeRental!.id} (${formatDate(_activeRental!.startDate)} - ${formatDate(_activeRental!.endDate)})'
                              : 'Aucune location active détectée sur cette date',
                          style: TextStyle(
                            fontSize: 12,
                            color: _activeRental != null
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Date
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Date de l'incident",
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: _pickDate,
                  validator: (v) => Validators.required(v, 'La date'),
                ),
                const SizedBox(height: 12),

                // 5. Lieu
                TextFormField(
                  controller: _placeController,
                  decoration: const InputDecoration(
                    labelText: 'Lieu (ville, route, repère)',
                  ),
                  validator: (v) => Validators.required(v, 'Le lieu'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),

                // 6. Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description des faits (minimum 10 caractères)',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 10) {
                      return 'Veuillez saisir une description détaillée (au moins 10 caractères)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // 7. Photos
                Text(
                  'Photos de constat (maximum 5)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                PhotoPickerField(
                  fileNames: _photos,
                  maxPhotos: 5,
                  onChanged: (list) => setState(() => _photos = list),
                ),
                const SizedBox(height: 16),

                // 8. Statut (edit only)
                if (_isEdit) ...[
                  DropdownButtonFormField<IncidentStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: [
                      for (final s in IncidentStatus.values)
                        DropdownMenuItem(value: s, child: Text(s.label)),
                    ],
                    onChanged: (s) {
                      if (s != null) setState(() => _status = s);
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text(Strings.save),
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
