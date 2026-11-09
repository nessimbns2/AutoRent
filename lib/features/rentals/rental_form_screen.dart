import 'dart:math';

import 'package:flutter/material.dart';

import '../../app/route_args.dart';
import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/constants/strings.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/app_exception.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../core/widgets/status_chips.dart';
import '../../models/client.dart';
import '../../models/enums.dart';
import '../../models/rental.dart';
import '../../models/vehicle.dart';
import '../../repositories/client_repository.dart';
import '../../repositories/maintenance_repository.dart';
import '../../repositories/rental_repository.dart';
import '../../repositories/vehicle_repository.dart';
import '../../core/services/contract_mailer.dart';
import 'widgets/booking_calendar.dart';

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
  DateTime _startDate = DateUtils.dateOnly(DateTime.now());
  DateTime _endDate =
      DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
  RentalStatus _status = RentalStatus.reservee;

  Set<String> _booked = {};
  bool _datesChosen = false;

  List<Client> _clients = [];
  List<Vehicle> _availableVehicles = [];
  Rental? _existing;
  bool _loading = true;
  bool _saving = false;

  bool get _isEdit => widget.rentalId != null;

  int get _days => max(1, _endDate.difference(_startDate).inDays);

  Vehicle? get _currentVehicle => _selectedVehicleId == null
      ? null
      : _availableVehicles.where((v) => v.id == _selectedVehicleId).firstOrNull;

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
        _datesChosen = true;
      }
    }
    await _updateAvailableVehicles();
    if (mounted) setState(() => _loading = false);
  }

  /// Every rentable vehicle; dates are chosen afterwards on its calendar.
  Future<void> _updateAvailableVehicles() async {
    final list = await _vehicleRepo.getAll(availableOnly: true);
    // Keep the vehicle of an edited contract selectable.
    if (_isEdit &&
        _selectedVehicleId != null &&
        !list.any((v) => v.id == _selectedVehicleId)) {
      final v = await _vehicleRepo.getById(_selectedVehicleId!);
      if (v != null) list.insert(0, v);
    }
    if (_selectedVehicleId != null) {
      _booked = await _rentalRepo.bookedDays(_selectedVehicleId!,
          excludeId: widget.rentalId);
    }
    if (mounted) setState(() => _availableVehicles = list);
  }

  Future<void> _selectVehicle(int? id) async {
    if (id == _selectedVehicleId) return;
    final booked = id == null
        ? <String>{}
        : await _rentalRepo.bookedDays(id, excludeId: widget.rentalId);
    if (!mounted) return;
    setState(() {
      _selectedVehicleId = id;
      _booked = booked;
      _datesChosen = false; // dates must be re-picked on this car's calendar
    });
  }

  Future<void> _createNewClient() async {
    final saved = await Navigator.pushNamed(context, Routes.clientForm);
    if (saved == true && mounted) {
      final list = await _clientRepo.getAll();
      final newest = [...list]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      setState(() {
        _clients = list;
        if (newest.isNotEmpty) _selectedClientId = newest.first.id;
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
    if (!_datesChosen) {
      showSnack(context, 'Choisissez les dates sur le calendrier');
      return;
    }

    setState(() => _saving = true);
    try {
      final vehicle = await _vehicleRepo.getById(_selectedVehicleId!);
      if (vehicle == null || !vehicle.available) {
        throw const AppException(Strings.vehicleNotAvailable);
      }
      if (await _maintenanceRepo.hasActiveMaintenance(_selectedVehicleId!)) {
        throw const AppException(Strings.vehicleInMaintenance);
      }
      final overlap = await _rentalRepo.hasOverlap(
        _selectedVehicleId!,
        _startDate,
        _endDate,
        excludeId: widget.rentalId,
      );
      if (overlap) throw const AppException(Strings.rentalOverlap);

      final rental = Rental(
        id: _existing?.id,
        clientId: _selectedClientId!,
        vehicleId: _selectedVehicleId!,
        userId: _existing?.userId ?? SessionManager.instance.currentUser?.id,
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
        final view = await _rentalRepo.getViewById(newId);
        final client =
            _clients.where((c) => c.id == _selectedClientId).firstOrNull;
        final email = client?.email?.trim();
        if (view != null && email != null && email.isNotEmpty) {
          if (!mounted) return;
          showSnack(context, 'Envoi du contrat à $email…');
          // The rental is already saved: a mail failure must not block it.
          try {
            await emailContract(view, email);
            if (mounted) {
              showSnack(context, 'Contrat envoyé à $email',
                  kind: SnackKind.success);
            }
          } on AppException catch (e) {
            if (mounted) showSnack(context, e.message, kind: SnackKind.error);
          }
        }
        if (!mounted) return;
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            // 1. Client ------------------------------------------------------
            FormSection(
              title: '1 · Locataire',
              icon: Icons.person_rounded,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedClientId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Choisir un locataire',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: [
                        for (final c in _clients)
                          DropdownMenuItem(
                            value: c.id,
                            child: Text(c.fullName,
                                overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (id) =>
                          setState(() => _selectedClientId = id),
                      validator: (v) =>
                          v == null ? 'Choisissez un locataire' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 56,
                    width: 56,
                    child: IconButton.filledTonal(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                        foregroundColor: AppColors.brand,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                      onPressed: _createNewClient,
                      tooltip: 'Nouveau locataire',
                    ),
                  ),
                ]),
              ],
            ),

            // 2. Vehicle -----------------------------------------------------
            FormSection(
              title: '2 · Véhicule',
              icon: Icons.directions_car_rounded,
              color: AppColors.teal,
              children: [
                if (_availableVehicles.isEmpty)
                  const InfoBanner(
                    icon: Icons.event_busy_rounded,
                    color: AppColors.danger,
                    text: 'Aucun véhicule disponible à la location.',
                  )
                else
                  SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _availableVehicles.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final v = _availableVehicles[i];
                        return _VehicleOption(
                          vehicle: v,
                          selected: v.id == _selectedVehicleId,
                          onTap: () => _selectVehicle(v.id),
                        );
                      },
                    ),
                  ),
              ],
            ),

            // 3. Period: only once a vehicle is chosen -----------------------
            FormSection(
              title: '3 · Période',
              icon: Icons.date_range_rounded,
              color: AppColors.info,
              children: [
                if (_selectedVehicleId == null)
                  const InfoBanner(
                    icon: Icons.directions_car_rounded,
                    color: AppColors.info,
                    text:
                        'Choisissez d\'abord un véhicule pour voir ses jours libres.',
                  )
                else ...[
                  BookingCalendar(
                    key: ValueKey(_selectedVehicleId),
                    booked: _booked,
                    start: _datesChosen ? _startDate : null,
                    end: _datesChosen ? _endDate : null,
                    firstDay: _isEdit && _startDate.isBefore(DateTime.now())
                        ? _startDate
                        : DateUtils.dateOnly(DateTime.now()),
                    onChanged: (s, e) => setState(() {
                      _startDate = s;
                      _endDate = e;
                      _datesChosen = true;
                    }),
                  ),
                  Text(
                    _datesChosen
                        ? 'Du ${formatDayMonth(_startDate)} au ${formatDayMonth(_endDate)} · $_days jour(s)'
                        : 'Touchez le jour de départ, puis le jour de retour.',
                    style: context.text.bodySmall,
                  ),
                ],
              ],
            ),

            // 4. Status (edit only) -----------------------------------------
            if (_isEdit)
              FormSection(
                title: 'Statut',
                icon: Icons.flag_rounded,
                color: AppColors.violet,
                children: [
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in RentalStatus.values)
                      ChoiceChip(
                        label: Text(s.label),
                        selected: _status == s,
                        showCheckmark: false,
                        selectedColor:
                            rentalStatusColor(s).withValues(alpha: 0.15),
                        labelStyle: context.text.labelMedium?.copyWith(
                            color: _status == s ? rentalStatusColor(s) : null),
                        onSelected: (_) => setState(() => _status = s),
                      ),
                  ]),
                ],
              ),
          ],
        ),
      ),
      bottomNavigationBar: BottomActionBar(
        child: Row(children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  _currentVehicle == null
                      ? 'Total estimé'
                      : '$_days j × ${_currentVehicle!.pricePerDay.toStringAsFixed(0)} DT',
                  style: context.text.bodySmall),
              Text(formatMoneyShort(_totalPrice),
                  style: context.text.titleLarge
                      ?.copyWith(color: AppColors.brand)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: PrimaryButton(
              label: _isEdit ? 'Enregistrer' : 'Confirmer',
              icon: Icons.check_rounded,
              loading: _saving,
              onPressed: _save,
            ),
          ),
        ]),
      ),
    );
  }
}

class _VehicleOption extends StatelessWidget {
  final Vehicle vehicle;
  final bool selected;
  final VoidCallback onTap;
  const _VehicleOption({
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 150,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg - 2),
            border: Border.all(
              color: selected ? AppColors.brand : context.palette.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(fit: StackFit.expand, children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: CarImage(
                      fileName: vehicle.photos.isNotEmpty
                          ? vehicle.photos.first
                          : null,
                      seed: vehicle.id ?? 0,
                    ),
                  ),
                  if (selected)
                    const Positioned(
                      right: 6,
                      top: 6,
                      child: CircleAvatar(
                        radius: 11,
                        backgroundColor: AppColors.brand,
                        child: Icon(Icons.check_rounded,
                            size: 14, color: Colors.white),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${vehicle.brand} ${vehicle.model}',
                        style: context.text.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('${vehicle.pricePerDay.toStringAsFixed(0)} DT/jour',
                        style: context.text.labelSmall
                            ?.copyWith(color: AppColors.brand)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
