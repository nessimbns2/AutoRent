import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/enums.dart';
import '../../models/maintenance.dart';
import '../../models/vehicle.dart';
import '../../repositories/maintenance_repository.dart';
import '../../repositories/vehicle_repository.dart';

class MaintenanceFormScreen extends StatefulWidget {
  final int? maintenanceId;
  final int? vehicleId;

  const MaintenanceFormScreen({
    super.key,
    this.maintenanceId,
    this.vehicleId,
  });

  @override
  State<MaintenanceFormScreen> createState() => _MaintenanceFormScreenState();
}

class _MaintenanceFormScreenState extends State<MaintenanceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _maintenanceRepo = MaintenanceRepository();
  final _vehicleRepo = VehicleRepository();

  int? _selectedVehicleId;
  String? _selectedType;
  DateTime _date = DateTime.now();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();
  MaintenanceStatus _status = MaintenanceStatus.planifie;

  List<Vehicle> _vehicles = [];
  Maintenance? _existing;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.maintenanceId != null;

  @override
  void initState() {
    super.initState();
    _selectedVehicleId = widget.vehicleId;
    _dateController.text = formatDate(_date);
    _load();
  }

  Future<void> _load() async {
    _vehicles = await _vehicleRepo.getAll();
    if (_isEdit) {
      _existing = await _maintenanceRepo.getById(widget.maintenanceId!);
      if (_existing != null) {
        _selectedVehicleId = _existing!.vehicleId;
        _selectedType = _existing!.type;
        _date = _existing!.date;
        _dateController.text = formatDate(_date);
        _descriptionController.text = _existing!.description ?? '';
        _status = _existing!.status;
      }
    } else {
      if (_selectedType == null && Strings.maintenanceTypes.isNotEmpty) {
        _selectedType = Strings.maintenanceTypes.first;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateController.text = formatDate(picked);
      });
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
      final desc = _descriptionController.text.trim();
      final maintenance = Maintenance(
        id: _existing?.id,
        vehicleId: _selectedVehicleId!,
        type: _selectedType!,
        date: _date,
        description: desc.isEmpty ? null : desc,
        status: _status,
        createdAt: _existing?.createdAt ?? DateTime.now(),
      );

      if (_isEdit) {
        await _maintenanceRepo.update(maintenance);
        if (!mounted) return;
        showSnack(context, Strings.maintenanceUpdated);
      } else {
        await _maintenanceRepo.insert(maintenance);
        if (!mounted) return;
        showSnack(context, Strings.maintenanceAdded);
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
        title: Text(_isEdit ? "Modifier l'entretien" : 'Planifier un entretien'),
      ),
      body: SafeArea(
        child: ResponsiveCenter(
          maxWidth: 750,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
            key: _formKey,
            child: Column(
              children: [
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
                      : (id) => setState(() => _selectedVehicleId = id),
                  validator: (v) => v == null ? 'Choisissez un véhicule' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _selectedType,
                  decoration: const InputDecoration(labelText: "Type d'intervention"),
                  items: [
                    for (final t in Strings.maintenanceTypes)
                      DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: (t) => setState(() => _selectedType = t),
                  validator: (v) =>
                      v == null ? "Choisissez un type d'entretien" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Date prévue',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: _pickDate,
                  validator: (v) => Validators.required(v, 'La date'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description / Observations (facultatif)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<MaintenanceStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Statut'),
                  items: [
                    for (final s in MaintenanceStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (s) {
                    if (s != null) setState(() => _status = s);
                  },
                ),
                const SizedBox(height: 24),
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
