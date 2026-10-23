// Enums used across the AutoRent domain.
// No Flutter imports — plain Dart only.

enum RentalStatus {
  reservee('reservee', 'Réservée'),
  enCours('en_cours', 'En cours'),
  terminee('terminee', 'Terminée'),
  annulee('annulee', 'Annulée');

  const RentalStatus(this.value, this.label);
  final String value;
  final String label;

  static RentalStatus fromValue(String v) =>
      RentalStatus.values.firstWhere((s) => s.value == v);
}

enum MaintenanceStatus {
  planifie('planifie', 'Planifié'),
  enCours('en_cours', 'En cours'),
  termine('termine', 'Terminé');

  const MaintenanceStatus(this.value, this.label);
  final String value;
  final String label;

  static MaintenanceStatus fromValue(String v) =>
      MaintenanceStatus.values.firstWhere((s) => s.value == v);
}

enum IncidentType {
  accident('accident', 'Accident'),
  panne('panne', 'Panne');

  const IncidentType(this.value, this.label);
  final String value;
  final String label;

  static IncidentType fromValue(String v) =>
      IncidentType.values.firstWhere((s) => s.value == v);
}

enum IncidentStatus {
  enAttente('en_attente', 'En attente'),
  enCours('en_cours', 'En cours'),
  resolu('resolu', 'Résolu');

  const IncidentStatus(this.value, this.label);
  final String value;
  final String label;

  static IncidentStatus fromValue(String v) =>
      IncidentStatus.values.firstWhere((s) => s.value == v);
}

/// Computed availability of a vehicle (not stored, derived at query time).
enum VehicleAvailability {
  disponible('Disponible'),
  louee('Louée'),
  enEntretien('En entretien'),
  indisponible('Indisponible');

  const VehicleAvailability(this.label);
  final String label;
}
