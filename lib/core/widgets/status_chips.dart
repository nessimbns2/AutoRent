import 'package:flutter/material.dart';

import '../../models/enums.dart';
import 'shared_widgets.dart';

/// Returns the semantic color and label for each enum value.
StatusChip rentalStatusChip(RentalStatus s) {
  final color = switch (s) {
    RentalStatus.reservee => Colors.orange,
    RentalStatus.enCours => Colors.blue,
    RentalStatus.terminee => Colors.green,
    RentalStatus.annulee => Colors.red,
  };
  return StatusChip(label: s.label, color: color);
}

StatusChip maintenanceStatusChip(MaintenanceStatus s) {
  final color = switch (s) {
    MaintenanceStatus.planifie => Colors.orange,
    MaintenanceStatus.enCours => Colors.blue,
    MaintenanceStatus.termine => Colors.green,
  };
  return StatusChip(label: s.label, color: color);
}

StatusChip incidentStatusChip(IncidentStatus s) {
  final color = switch (s) {
    IncidentStatus.enAttente => Colors.orange,
    IncidentStatus.enCours => Colors.blue,
    IncidentStatus.resolu => Colors.green,
  };
  return StatusChip(label: s.label, color: color);
}

StatusChip vehicleAvailabilityChip(VehicleAvailability s) {
  final color = switch (s) {
    VehicleAvailability.disponible => Colors.green,
    VehicleAvailability.louee => Colors.blue,
    VehicleAvailability.enEntretien => Colors.orange,
    VehicleAvailability.indisponible => Colors.red,
  };
  return StatusChip(label: s.label, color: color);
}
