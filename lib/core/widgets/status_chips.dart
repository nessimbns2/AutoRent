import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../models/enums.dart';
import '../../models/rental.dart';
import '../../models/vehicle.dart';
import '../../models/vehicle_document.dart';
import '../constants/business_rules.dart';
import 'shared_widgets.dart';

// Semantic colours & icons for every status enum, so lists, details and the
// dashboard all speak the same visual language.

Color rentalStatusColor(RentalStatus s) => switch (s) {
      RentalStatus.reservee => AppColors.warning,
      RentalStatus.enCours => AppColors.info,
      RentalStatus.terminee => AppColors.success,
      RentalStatus.annulee => AppColors.danger,
    };

IconData rentalStatusIcon(RentalStatus s) => switch (s) {
      RentalStatus.reservee => Icons.event_available_rounded,
      RentalStatus.enCours => Icons.directions_car_rounded,
      RentalStatus.terminee => Icons.task_alt_rounded,
      RentalStatus.annulee => Icons.cancel_rounded,
    };

Color maintenanceStatusColor(MaintenanceStatus s) => switch (s) {
      MaintenanceStatus.planifie => AppColors.warning,
      MaintenanceStatus.enCours => AppColors.info,
      MaintenanceStatus.termine => AppColors.success,
    };

Color incidentStatusColor(IncidentStatus s) => switch (s) {
      IncidentStatus.enAttente => AppColors.danger,
      IncidentStatus.enCours => AppColors.info,
      IncidentStatus.resolu => AppColors.success,
    };

Color incidentTypeColor(IncidentType t) => switch (t) {
      IncidentType.accident => AppColors.danger,
      IncidentType.panne => AppColors.warning,
    };

IconData incidentTypeIcon(IncidentType t) => switch (t) {
      IncidentType.accident => Icons.car_crash_rounded,
      IncidentType.panne => Icons.car_repair_rounded,
    };

Color vehicleAvailabilityColor(VehicleAvailability s) => switch (s) {
      VehicleAvailability.disponible => AppColors.success,
      VehicleAvailability.louee => AppColors.info,
      VehicleAvailability.enEntretien => AppColors.warning,
      VehicleAvailability.documentsExpires => AppColors.violet,
      VehicleAvailability.indisponible => AppColors.danger,
      VehicleAvailability.archivee => AppColors.muted,
    };

IconData maintenanceTypeIcon(String type) => switch (type) {
      'Vidange' => Icons.oil_barrel_rounded,
      'Pneus' => Icons.tire_repair_rounded,
      'Freins' => Icons.album_rounded,
      'Révision' => Icons.fact_check_rounded,
      'Batterie' => Icons.battery_charging_full_rounded,
      _ => Icons.build_rounded,
    };

Color documentStatusColor(DocumentStatus s) => switch (s) {
      DocumentStatus.valid => AppColors.success,
      DocumentStatus.expiringSoon => AppColors.warning,
      DocumentStatus.expired => AppColors.danger,
      DocumentStatus.missing => AppColors.muted,
    };

IconData documentTypeIcon(DocumentType t) => switch (t) {
      DocumentType.assurance => Icons.shield_rounded,
      DocumentType.visiteTechnique => Icons.fact_check_rounded,
      DocumentType.vignette => Icons.receipt_rounded,
      DocumentType.carteGrise => Icons.badge_rounded,
    };

IconData fuelIcon(FuelType f) => switch (f) {
      FuelType.essence => Icons.local_gas_station_rounded,
      FuelType.diesel => Icons.local_gas_station_outlined,
      FuelType.hybride => Icons.energy_savings_leaf_rounded,
      FuelType.electrique => Icons.ev_station_rounded,
    };

/// "Expire dans 5 j", "Expirée depuis 2 j", "Valide jusqu'au …".
StatusChip documentStatusChip(DateTime? expiresOn) {
  final s = BusinessRules.documentStatus(expiresOn);
  if (expiresOn == null) {
    return StatusChip(label: s.label, color: documentStatusColor(s));
  }
  final d = BusinessRules.daysUntil(expiresOn);
  final label = switch (s) {
    DocumentStatus.expired => 'Expiré (${-d} j)',
    DocumentStatus.expiringSoon => d == 0 ? "Expire aujourd'hui" : 'Expire dans $d j',
    _ => 'Valide',
  };
  return StatusChip(label: label, color: documentStatusColor(s));
}

/// A rental still "en cours" after its end date is overdue.
bool isRentalOverdue(Rental r) {
  if (r.status != RentalStatus.enCours) return false;
  final today = DateUtils.dateOnly(DateTime.now());
  return DateUtils.dateOnly(r.endDate).isBefore(today);
}

StatusChip rentalStatusChip(RentalStatus s, {bool overdue = false}) => overdue
    ? const StatusChip(
        label: 'En retard',
        color: AppColors.danger,
        icon: Icons.schedule_rounded)
    : StatusChip(label: s.label, color: rentalStatusColor(s));

StatusChip maintenanceStatusChip(MaintenanceStatus s) =>
    StatusChip(label: s.label, color: maintenanceStatusColor(s));

StatusChip incidentStatusChip(IncidentStatus s) =>
    StatusChip(label: s.label, color: incidentStatusColor(s));

StatusChip vehicleAvailabilityChip(VehicleAvailability s,
        {bool solid = false}) =>
    StatusChip(
        label: s.label, color: vehicleAvailabilityColor(s), solid: solid);
