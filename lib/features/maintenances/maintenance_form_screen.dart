import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/constants/strings.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
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
  String _selectedType = Strings.maintenanceTypes.first;
  DateTime _date = DateTime.now();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _costEstimatedController = TextEditingController();
  final _mileageController = TextEditingController();
  final _garageController = TextEditingController();
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
        _costEstimatedController.text =
            _existing!.costEstimated?.toStringAsFixed(0) ?? '';
        _mileageController.text =
            _existing!.mileage?.toString() ?? '';
        _garageController.text = _existing!.garage ?? '';
        _status = _existing!.status;
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _dateController.dispose();
    _descriptionController.dispose();
    _costEstimatedController.dispose();
    _mileageController.dispose();
    _garageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: "Date de l'intervention",
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
      final costText = _costEstimatedController.text.trim();
      final mileageText = _mileageController.text.trim();
      final garageText = _garageController.text.trim();
      final maintenance = Maintenance(
        id: _existing?.id,
        vehicleId: _selectedVehicleId!,
        type: _selectedType,
        date: _date,
        description: desc.isEmpty ? null : desc,
        status: _status,
        createdAt: _existing?.createdAt ?? DateTime.now(),
        costEstimated: costText.isEmpty ? null : double.tryParse(costText),
        costActual: _existing?.costActual,
        mileage: mileageText.isEmpty ? null : int.tryParse(mileageText),
        garage: garageText.isEmpty ? null : garageText,
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
        title:
            Text(_isEdit ? "Modifier l'entretien" : 'Planifier un entretien'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
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
                      : (id) => setState(() => _selectedVehicleId = id),
                  validator: (v) => v == null ? 'Choisissez un véhicule' : null,
                ),
              ],
            ),
            FormSection(
              title: "Type d'intervention",
              icon: Icons.handyman_rounded,
              color: AppColors.teal,
              children: [
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.15,
                  children: [
                    for (final t in Strings.maintenanceTypes)
                      _TypeOption(
                        label: t,
                        icon: maintenanceTypeIcon(t),
                        selected: _selectedType == t,
                        onTap: () => setState(() => _selectedType = t),
                      ),
                  ],
                ),
              ],
            ),
            FormSection(
              title: 'Planification',
              icon: Icons.event_rounded,
              color: AppColors.info,
              children: [
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Date prévue',
                    prefixIcon: Icon(Icons.calendar_today_rounded),
                  ),
                  onTap: _pickDate,
                  validator: (v) => Validators.required(v, 'La date'),
                ),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observations (facultatif)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
            FormSection(
              title: 'Coût & kilométrage',
              icon: Icons.attach_money_rounded,
              color: AppColors.success,
              children: [
                TextFormField(
                  controller: _costEstimatedController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Coût estimé (DT)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                TextFormField(
                  controller: _mileageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Kilométrage (km)',
                    prefixIcon: Icon(Icons.speed_rounded),
                  ),
                ),
                TextFormField(
                  controller: _garageController,
                  decoration: const InputDecoration(
                    labelText: 'Garage / prestataire',
                    prefixIcon: Icon(Icons.store_rounded),
                  ),
                ),
              ],
            ),
            FormSection(
              title: 'Statut',
              icon: Icons.flag_rounded,
              color: AppColors.info,
              children: [
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in MaintenanceStatus.values)
                    ChoiceChip(
                      label: Text(s.label),
                      selected: _status == s,
                      showCheckmark: false,
                      selectedColor:
                          maintenanceStatusColor(s).withValues(alpha: 0.15),
                      labelStyle: context.text.labelMedium?.copyWith(
                          color:
                              _status == s ? maintenanceStatusColor(s) : null),
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
          label: _isEdit ? 'Enregistrer' : "Planifier l'entretien",
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.teal.withValues(alpha: 0.12)
                : context.palette.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
                color: selected ? AppColors.teal : Colors.transparent,
                width: 1.6),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: selected ? AppColors.teal : context.palette.muted),
              const SizedBox(height: 6),
              Text(label,
                  style: context.text.labelMedium?.copyWith(
                      color: selected ? AppColors.teal : null)),
            ],
          ),
        ),
      );
}
