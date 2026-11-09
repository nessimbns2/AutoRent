import 'package:flutter/material.dart';

import '../../app/theme.dart';
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

  static const _popularBrands = [
    'Peugeot', 'Renault', 'Toyota', 'Volkswagen', 'Kia', 'Hyundai',
    'Dacia', 'Citroën', 'Fiat', 'Seat',
  ];

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
        _priceController.text = _existing!.pricePerDay.toStringAsFixed(0);
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            FormSection(
              title: 'Photos',
              icon: Icons.photo_camera_back_rounded,
              color: AppColors.violet,
              children: [
                PhotoPickerField(
                  fileNames: _photos,
                  maxPhotos: 6,
                  onChanged: (list) => setState(() => _photos = list),
                ),
                Text('La première photo sert de couverture (6 maximum).',
                    style: context.text.bodySmall),
              ],
            ),
            FormSection(
              title: 'Identification',
              icon: Icons.directions_car_rounded,
              children: [
                TextFormField(
                  controller: _brandController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Marque',
                    prefixIcon: Icon(Icons.local_offer_outlined),
                  ),
                  validator: (v) => Validators.required(v, 'La marque'),
                  textInputAction: TextInputAction.next,
                ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final b in _popularBrands)
                      ActionChip(
                        label: Text(b),
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            setState(() => _brandController.text = b),
                      ),
                  ],
                ),
                TextFormField(
                  controller: _modelController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Modèle',
                    prefixIcon: Icon(Icons.directions_car_outlined),
                  ),
                  validator: (v) => Validators.required(v, 'Le modèle'),
                  textInputAction: TextInputAction.next,
                ),
                TextFormField(
                  controller: _plateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Immatriculation',
                    hintText: '123 TUN 4567',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: Validators.plate,
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),
            FormSection(
              title: 'Tarification & disponibilité',
              icon: Icons.payments_rounded,
              color: AppColors.success,
              children: [
                TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Prix par jour',
                    prefixIcon: Icon(Icons.sell_outlined),
                    suffixText: 'DT',
                  ),
                  validator: (v) => Validators.positiveNumber(v, 'Le prix'),
                  textInputAction: TextInputAction.done,
                ),
                Container(
                  decoration: BoxDecoration(
                    color: context.palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: SwitchListTile(
                    value: _available,
                    onChanged: (val) => setState(() => _available = val),
                    title: const Text('Disponible à la location'),
                    subtitle: Text(
                      _available
                          ? 'Le véhicule peut être réservé.'
                          : 'Le véhicule est retiré de la location.',
                      style: context.text.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: _isEdit ? 'Enregistrer les modifications' : 'Ajouter le véhicule',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
