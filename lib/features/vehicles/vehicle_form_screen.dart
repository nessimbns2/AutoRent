import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/plate_formatter.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/utils/validators.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/vehicle.dart';
import '../../models/vehicle_document.dart';
import '../../repositories/vehicle_document_repository.dart';
import '../../repositories/vehicle_repository.dart';

/// Create / edit / duplicate a vehicle: identification, technical sheet,
/// pricing, photos (with cover) and administrative documents.
class VehicleFormScreen extends StatefulWidget {
  final int? vehicleId;
  final int? duplicateFromId;
  const VehicleFormScreen({super.key, this.vehicleId, this.duplicateFromId});

  @override
  State<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends State<VehicleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = VehicleRepository();
  final _docRepo = VehicleDocumentRepository();

  final _brandController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _priceController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _mileageController = TextEditingController();

  static const _popularBrands = [
    'Peugeot', 'Renault', 'Toyota', 'Volkswagen', 'Kia', 'Hyundai',
    'Dacia', 'Citroën', 'Suzuki', 'Škoda',
  ];
  static const _colors = ['Blanc', 'Noir', 'Gris', 'Rouge', 'Bleu', 'Vert'];
  static const _seatOptions = [2, 4, 5, 7, 9];

  VehicleCategory? _category;
  FuelType? _fuel;
  Gearbox? _gearbox;
  int? _seats = 5;
  bool _available = true;
  List<String> _photos = [];

  final Map<DocumentType, DateTime?> _docDates = {
    for (final t in DocumentType.values) t: null
  };
  final Map<DocumentType, TextEditingController> _docNumbers = {
    for (final t in DocumentType.values) t: TextEditingController()
  };

  Vehicle? _existing;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.vehicleId != null;
  bool get _isDuplicate => widget.duplicateFromId != null && !_isEdit;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sourceId = widget.vehicleId ?? widget.duplicateFromId;
    if (sourceId != null) {
      final v = await _repo.getById(sourceId);
      if (v != null) {
        if (_isEdit) _existing = v;
        _brandController.text = v.brand;
        _modelController.text = v.model;
        _priceController.text = v.pricePerDay.toStringAsFixed(0);
        _yearController.text = v.year?.toString() ?? '';
        _colorController.text = v.color ?? '';
        _category = v.category;
        _fuel = v.fuel;
        _gearbox = v.gearbox;
        _seats = v.seats ?? _seats;
        _available = v.available;
        if (_isEdit) {
          // A copy gets its own plate, photos, mileage and documents.
          _plateController.text = v.plate;
          _mileageController.text = v.mileage?.toString() ?? '';
          _photos = List<String>.from(v.photos);
          final docs = await _docRepo.getByVehicle(v.id!);
          for (final e in docs.entries) {
            _docDates[e.key] = e.value.expiresOn;
            _docNumbers[e.key]!.text = e.value.number ?? '';
          }
        }
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    for (final c in [
      _brandController,
      _modelController,
      _plateController,
      _priceController,
      _yearController,
      _colorController,
      _mileageController,
      ..._docNumbers.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _intOf(TextEditingController c) =>
      int.tryParse(c.text.trim().replaceAll(' ', ''));

  Future<void> _pickDocDate(DocumentType t) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _docDates[t] ?? now.add(const Duration(days: 365)),
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 15),
      helpText: "Date d'expiration · ${t.label}",
    );
    if (picked != null) setState(() => _docDates[t] = picked);
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
        plate: TunisianPlateFormatter.format(_plateController.text),
        pricePerDay: price,
        available: _available,
        photos: _photos,
        createdAt: _existing?.createdAt ?? DateTime.now(),
        category: _category,
        fuel: _fuel,
        gearbox: _gearbox,
        seats: _seats,
        year: _intOf(_yearController),
        color: _colorController.text.trim().isEmpty
            ? null
            : _colorController.text.trim(),
        mileage: _intOf(_mileageController),
        archived: _existing?.archived ?? false,
        archivedAt: _existing?.archivedAt,
      );

      final int id;
      if (_isEdit) {
        await _repo.update(vehicle);
        id = vehicle.id!;
      } else {
        id = await _repo.insert(vehicle);
      }
      await _docRepo.saveAll(id, {
        for (final t in DocumentType.values)
          t: (expiresOn: _docDates[t], number: _docNumbers[t]!.text),
      });
      if (!mounted) return;
      showSnack(context, _isEdit ? 'Véhicule modifié' : 'Véhicule ajouté');
      Navigator.pop(context, true);
    } on AppException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _choiceChips<T>({
    required List<T> values,
    required T? selected,
    required String Function(T) label,
    required ValueChanged<T?> onSelected,
    IconData Function(T)? icon,
  }) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final v in values)
          ChoiceChip(
            avatar: icon == null
                ? null
                : Icon(icon(v),
                    size: 16,
                    color: selected == v ? AppColors.brand : null),
            label: Text(label(v)),
            selected: selected == v,
            showCheckmark: false,
            selectedColor: AppColors.brand.withValues(alpha: 0.14),
            labelStyle: context.text.labelMedium
                ?.copyWith(color: selected == v ? AppColors.brand : null),
            onSelected: (on) => onSelected(on ? v : null),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingView());
    final thisYear = DateTime.now().year;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit
            ? 'Modifier le véhicule'
            : _isDuplicate
                ? 'Dupliquer le véhicule'
                : 'Nouveau véhicule'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            if (_isDuplicate)
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: InfoBanner(
                  icon: Icons.copy_rounded,
                  text:
                      'Copie pré-remplie : saisissez l\'immatriculation, le kilométrage, '
                      'les photos et les documents de ce nouveau véhicule.',
                ),
              ),

            // ── Photos ────────────────────────────────────────────────────
            FormSection(
              title: 'Photos',
              icon: Icons.photo_camera_back_rounded,
              color: AppColors.violet,
              children: [
                PhotoPickerField(
                  fileNames: _photos,
                  maxPhotos: 6,
                  coverSelectable: true,
                  onChanged: (list) => setState(() => _photos = list),
                ),
                Text(
                    "Touchez l'étoile d'une photo pour en faire la couverture (6 maximum).",
                    style: context.text.bodySmall),
              ],
            ),

            // ── Identification ────────────────────────────────────────────
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
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final b in _popularBrands)
                    ActionChip(
                      label: Text(b),
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          setState(() => _brandController.text = b),
                    ),
                ]),
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
                  inputFormatters: [TunisianPlateFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Immatriculation',
                    hintText: '123 TUN 4567',
                    helperText: 'Tapez les chiffres, « TUN » est ajouté automatiquement',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: Validators.plate,
                  textInputAction: TextInputAction.next,
                ),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: TextFormField(
                      controller: _yearController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Année',
                        prefixIcon: Icon(Icons.event_rounded),
                      ),
                      validator: (v) => Validators.optionalIntRange(
                          v, 1990, thisYear + 1, "L'année"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _colorController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Couleur',
                        prefixIcon: Icon(Icons.palette_outlined),
                      ),
                    ),
                  ),
                ]),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final c in _colors)
                    ActionChip(
                      label: Text(c),
                      visualDensity: VisualDensity.compact,
                      onPressed: () =>
                          setState(() => _colorController.text = c),
                    ),
                ]),
              ],
            ),

            // ── Technical sheet ───────────────────────────────────────────
            FormSection(
              title: 'Caractéristiques',
              icon: Icons.tune_rounded,
              color: AppColors.info,
              children: [
                Text('Catégorie', style: context.text.labelMedium),
                _choiceChips<VehicleCategory>(
                  values: VehicleCategory.values,
                  selected: _category,
                  label: (c) => c.label,
                  onSelected: (c) => setState(() => _category = c),
                ),
                Text('Carburant', style: context.text.labelMedium),
                _choiceChips<FuelType>(
                  values: FuelType.values,
                  selected: _fuel,
                  label: (f) => f.label,
                  icon: fuelIcon,
                  onSelected: (f) => setState(() => _fuel = f),
                ),
                Text('Boîte de vitesses', style: context.text.labelMedium),
                _choiceChips<Gearbox>(
                  values: Gearbox.values,
                  selected: _gearbox,
                  label: (g) => g.label,
                  onSelected: (g) => setState(() => _gearbox = g),
                ),
                Text('Nombre de places', style: context.text.labelMedium),
                _choiceChips<int>(
                  values: _seatOptions,
                  selected: _seats,
                  label: (n) => '$n places',
                  onSelected: (n) => setState(() => _seats = n),
                ),
                TextFormField(
                  controller: _mileageController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Kilométrage actuel',
                    prefixIcon: Icon(Icons.speed_rounded),
                    suffixText: 'km',
                  ),
                  validator: (v) => Validators.optionalIntRange(
                      v, 0, 2000000, 'Le kilométrage'),
                ),
              ],
            ),

            // ── Pricing ───────────────────────────────────────────────────
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
                ),
                Material(
                  // ListTile paints on the nearest Material: give it one.
                  color: context.palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  clipBehavior: Clip.antiAlias,
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

            // ── Documents ─────────────────────────────────────────────────
            FormSection(
              title: 'Documents administratifs',
              icon: Icons.folder_shared_rounded,
              color: AppColors.violet,
              children: [
                const InfoBanner(
                  icon: Icons.gavel_rounded,
                  color: AppColors.violet,
                  text:
                      "Sans assurance ou visite technique valides, le véhicule ne peut pas être loué. "
                      "Une alerte est envoyée 30 jours avant chaque échéance.",
                ),
                for (final t in DocumentType.values) _DocumentInput(
                  type: t,
                  date: _docDates[t],
                  number: _docNumbers[t]!,
                  onPickDate: () => _pickDocDate(t),
                  onClear: () => setState(() => _docDates[t] = null),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: PrimaryButton(
          label: _isEdit
              ? 'Enregistrer les modifications'
              : 'Ajouter le véhicule',
          icon: Icons.check_rounded,
          loading: _saving,
          onPressed: _save,
        ),
      ),
    );
  }
}

class _DocumentInput extends StatelessWidget {
  final DocumentType type;
  final DateTime? date;
  final TextEditingController number;
  final VoidCallback onPickDate;
  final VoidCallback onClear;
  const _DocumentInput({
    required this.type,
    required this.date,
    required this.number,
    required this.onPickDate,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(documentTypeIcon(type),
                  size: 18,
                  color: type.blocksRental
                      ? AppColors.violet
                      : context.palette.muted),
              const SizedBox(width: 8),
              Expanded(child: Text(type.label, style: context.text.titleSmall)),
              if (type.blocksRental)
                const StatusChip(
                    label: 'Obligatoire', color: AppColors.violet),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: InkWell(
                  onTap: onPickDate,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: "Date d'expiration",
                      isDense: true,
                      fillColor: context.colors.surface,
                      suffixIcon: date == null
                          ? const Icon(Icons.calendar_today_rounded, size: 18)
                          : IconButton(
                              tooltip: 'Effacer',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: onClear,
                            ),
                    ),
                    child: Text(
                      date == null ? 'Non renseignée' : formatDate(date!),
                      style: context.text.bodyMedium?.copyWith(
                          color: date == null ? context.palette.muted : null),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: number,
                  decoration: InputDecoration(
                    labelText: 'N° (facultatif)',
                    isDense: true,
                    fillColor: context.colors.surface,
                  ),
                ),
              ),
            ]),
            if (date != null) ...[
              const SizedBox(height: 8),
              Align(
                  alignment: Alignment.centerLeft,
                  child: documentStatusChip(date)),
            ],
          ],
        ),
      );
}
