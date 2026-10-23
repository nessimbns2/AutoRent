import 'dart:math';
import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../core/constants/strings.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../models/client.dart';
import '../../models/enums.dart';
import '../../models/rental.dart';
import '../../models/vehicle.dart';
import '../../repositories/client_repository.dart';
import '../../repositories/maintenance_repository.dart';
import '../../repositories/rental_repository.dart';
import '../../repositories/vehicle_repository.dart';

class RentalFormScreen extends StatefulWidget {
  final int? rentalId;
  final int? vehicleId;
  final int? clientId;

  const RentalFormScreen({
    super.key,
    this.rentalId,
    this.vehicleId,
    this.clientId,
  });

  @override
  State<RentalFormScreen> createState() => _RentalFormScreenState();
}

class _RentalFormScreenState extends State<RentalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rentalRepo = RentalRepository();
  final _vehicleRepo = VehicleRepository();
  final _clientRepo = ClientRepository();
  final _maintenanceRepo = MaintenanceRepository();

  int? _selectedClientId;
  int? _selectedVehicleId;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  RentalStatus _status = RentalStatus.reservee;

  List<Client> _clients = [];
  List<Vehicle> _availableVehicles = [];
  Rental? _existing;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.rentalId != null;

  int get _days => max(1, _endDate.difference(_startDate).inDays);

  Vehicle? get _currentVehicle {
    if (_selectedVehicleId == null) return null;
    return _availableVehicles
        .where((v) => v.id == _selectedVehicleId)
        .firstOrNull;
  }

  double get _totalPrice {
    final v = _currentVehicle;
    if (v == null) return _existing?.totalPrice ?? 0.0;
    return _days * v.pricePerDay;
  }

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.clientId;
    _selectedVehicleId = widget.vehicleId;
    _load();
  }

  Future<void> _load() async {
    _clients = await _clientRepo.getAll();
    final currentUser = SessionManager.instance.currentUser;
    if (!_isEdit && currentUser != null) {
      final myClient = await _clientRepo.getOrCreateForUser(currentUser);
      _selectedClientId ??= myClient.id;
      if (!_clients.any((c) => c.id == myClient.id)) {
        _clients.insert(0, myClient);
      }
    }
    if (_isEdit) {
      _existing = await _rentalRepo.getById(widget.rentalId!);
      if (_existing != null) {
        _selectedClientId = _existing!.clientId;
        _selectedVehicleId = _existing!.vehicleId;
        _startDate = _existing!.startDate;
        _endDate = _existing!.endDate;
        _status = _existing!.status;
      }
    }
    await _updateAvailableVehicles();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _updateAvailableVehicles() async {
    final list = await _vehicleRepo.getAvailableForRange(
      _startDate,
      _endDate,
      excludeRentalId: widget.rentalId,
    );
    // If the currently chosen vehicle is not in list but is existing, keep it
    if (_selectedVehicleId != null &&
        !list.any((v) => v.id == _selectedVehicleId)) {
      final v = await _vehicleRepo.getById(_selectedVehicleId!);
      if (v != null) list.insert(0, v);
    }
    if (mounted) {
      setState(() {
        _availableVehicles = list;
        if (_selectedVehicleId != null &&
            !_availableVehicles.any((v) => v.id == _selectedVehicleId)) {
          _selectedVehicleId = null;
        }
      });
    }
  }

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: _isEdit
          ? _startDate.subtract(const Duration(days: 365))
          : DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (range != null) {
      setState(() {
        _startDate = range.start;
        _endDate = range.end;
      });
      await _updateAvailableVehicles();
    }
  }

  Future<void> _createNewClient() async {
    final saved = await Navigator.pushNamed(
      context,
      Routes.clientForm,
    );
    if (saved == true && mounted) {
      final list = await _clientRepo.getAll();
      setState(() {
        _clients = list;
        if (list.isNotEmpty) {
          _selectedClientId = list.last.id;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClientId == null) {
      showSnack(context, 'Veuillez sélectionner un locataire');
      return;
    }
    if (_selectedVehicleId == null) {
      showSnack(context, 'Veuillez sélectionner un véhicule');
      return;
    }

    setState(() => _saving = true);
    try {
      // 1. Vehicle availability verification
      final vehicle = await _vehicleRepo.getById(_selectedVehicleId!);
      if (vehicle == null || !vehicle.available) {
        throw const AppException(Strings.vehicleNotAvailable);
      }
      if (await _maintenanceRepo.hasActiveMaintenance(_selectedVehicleId!)) {
        throw const AppException(Strings.vehicleInMaintenance);
      }

      // 2. Overlap check
      final overlap = await _rentalRepo.hasOverlap(
        _selectedVehicleId!,
        _startDate,
        _endDate,
        excludeId: widget.rentalId,
      );
      if (overlap) {
        throw const AppException(Strings.rentalOverlap);
      }

      final currentUserId = SessionManager.instance.currentUser?.id;

      final rental = Rental(
        id: _existing?.id,
        clientId: _selectedClientId!,
        vehicleId: _selectedVehicleId!,
        userId: _existing?.userId ?? currentUserId,
        startDate: _startDate,
        endDate: _endDate,
        totalPrice: _totalPrice,
        status: _status,
        createdAt: _existing?.createdAt ?? DateTime.now(),
      );

      if (_isEdit) {
        await _rentalRepo.update(rental);
        if (!mounted) return;
        showSnack(context, Strings.rentalUpdated);
        Navigator.pop(context, true);
      } else {
        final newId = await _rentalRepo.insert(rental);
        if (!mounted) return;
        showSnack(context, Strings.rentalAdded);
        Navigator.pushReplacementNamed(
          context,
          Routes.rentalDetail,
          arguments: IdArgs(newId),
          result: true,
        );
      }
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
        title: Text(_isEdit ? 'Modifier la location' : 'Nouvelle location'),
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
                  // 1. Locataire
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          initialValue: _selectedClientId,
                          decoration:
                              const InputDecoration(labelText: 'Locataire'),
                          items: [
                            for (final c in _clients)
                              DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  c.fullName,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (id) =>
                              setState(() => _selectedClientId = id),
                          validator: (v) =>
                              v == null ? 'Choisissez un locataire' : null,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: IconButton.filledTonal(
                          icon: const Icon(Icons.person_add),
                          onPressed: _createNewClient,
                          tooltip: 'Nouveau locataire',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 2. Dates
                  InkWell(
                    onTap: _pickDates,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Période de location',
                        suffixIcon: Icon(Icons.date_range),
                      ),
                      child: Text(
                        '${formatDate(_startDate)} → ${formatDate(_endDate)} ($_days jour(s))',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. Véhicule
                  DropdownButtonFormField<int>(
                    initialValue: _selectedVehicleId,
                    decoration: const InputDecoration(labelText: 'Véhicule'),
                    items: [
                      for (final v in _availableVehicles)
                        DropdownMenuItem(
                          value: v.id,
                          child: Text(
                            '${v.label} (${formatMoney(v.pricePerDay)}/j)',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (id) => setState(() => _selectedVehicleId = id),
                    validator: (v) => v == null ? 'Choisissez un véhicule' : null,
                  ),
                  if (_availableVehicles.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Aucun véhicule disponible sur cette période.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // 4. Total Price preview card
                  Card(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.5),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Montant estimé',
                                  style: TextStyle(fontSize: 12),
                                ),
                                Text(
                                  '$_days jour(s) × ${formatMoney(_currentVehicle?.pricePerDay ?? 0)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatMoney(_totalPrice),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                // 5. Statut (edit only)
                if (_isEdit) ...[
                  DropdownButtonFormField<RentalStatus>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'Statut'),
                    items: [
                      for (final s in RentalStatus.values)
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
