import 'package:flutter/material.dart';

import '../../core/constants/strings.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/vehicle.dart';
import '../../repositories/vehicle_repository.dart';

class VehicleFormScreen extends StatefulWidget {
  final int? vehicleId;
  const VehicleFormScreen({super.key, this.vehicleId});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = VehicleRepository();

  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _priceController = TextEditingController();

  bool _available = true;
  List<String> _photos = [];
  Vehicle? _existing;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.vehicleId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isEdit) {
      _existing = await _repo.getById(widget.vehicleId!);
      if (_existing != null) {
        _brandController.text = _existing!.brand;
        _modelController.text = _existing!.model;
        _plateController.text = _existing!.plate;
        _priceController.text = _existing!.pricePerDay.toStringAsFixed(2);
        _available = _existing!.available;
        _photos = List<String>.from(_existing!.photos);
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final price = double.parse(_priceController.text.replaceAll(',', '.'));
      final vehicle = Vehicle(
        id: _existing?.id,
        brand: _brandController.text.trim(),
        model: _modelController.text.trim(),
        plate: _plateController.text.trim().toUpperCase(),
        pricePerDay: price,
        available: _available,
        photos: _photos,
        createdAt: _existing?.createdAt ?? DateTime.now(),
      );

      if (_isEdit) {
        await _repo.update(vehicle);
        if (!mounted) return;
        showSnack(context, 'Véhicule modifié');
      } else {
        await _repo.insert(vehicle);
        if (!mounted) return;
        showSnack(context, 'Véhicule ajouté');
      }
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier le véhicule' : 'Nouveau véhicule'),
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
                TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(labelText: 'Marque'),
                  validator: (v) => Validators.required(v, 'La marque'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(labelText: 'Modèle'),
                  validator: (v) => Validators.required(v, 'Le modèle'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Immatriculation (ex: 123 TUN 4567)',
                  ),
                  validator: Validators.plate,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Prix de location par jour (DT)',
                  ),
                  validator: (v) => Validators.positiveNumber(v, 'Le prix'),
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Disponible à la location'),
                  subtitle: const Text(
                    'Interrupteur manuel activant ou désactivant la mise en location',
                  ),
                  value: _available,
                  onChanged: (val) => setState(() => _available = val),
                ),
                const SizedBox(height: 16),
                Text(
                  'Photos du véhicule (maximum 6)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                PhotoPickerField(
                  fileNames: _photos,
                  maxPhotos: 6,
                  onChanged: (list) => setState(() => _photos = list),
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
