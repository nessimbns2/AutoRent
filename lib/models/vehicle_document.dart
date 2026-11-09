/// Administrative documents of a vehicle (table `vehicle_documents`).
enum DocumentType {
  assurance('assurance', 'Assurance', blocksRental: true),
  visiteTechnique('visite_technique', 'Visite technique', blocksRental: true),
  vignette('vignette', 'Vignette', blocksRental: false),
  carteGrise('carte_grise', 'Carte grise', blocksRental: false);

  const DocumentType(this.value, this.label, {required this.blocksRental});
  final String value;
  final String label;

  /// A vehicle cannot be rented when this document is expired
  /// (legal obligation: insurance and roadworthiness test).
  final bool blocksRental;

  static DocumentType fromValue(String v) =>
      DocumentType.values.firstWhere((e) => e.value == v);
}

/// Validity of a document compared with today.
enum DocumentStatus {
  valid('Valide'),
  expiringSoon('Bientôt expiré'),
  expired('Expiré'),
  missing('Non renseigné');

  const DocumentStatus(this.label);
  final String label;
}

class VehicleDocument {
  final int? id;
  final int vehicleId;
  final DocumentType type;
  final String? number;
  final DateTime expiresOn;
  final DateTime updatedAt;

  const VehicleDocument({
    this.id,
    required this.vehicleId,
    required this.type,
    this.number,
    required this.expiresOn,
    required this.updatedAt,
  });

  factory VehicleDocument.fromMap(Map<String, Object?> m) => VehicleDocument(
        id: m['id'] as int?,
        vehicleId: m['vehicle_id'] as int,
        type: DocumentType.fromValue(m['type'] as String),
        number: m['numero'] as String?,
        expiresOn: DateTime.parse(m['date_expiration'] as String),
        updatedAt: DateTime.parse(m['updated_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'vehicle_id': vehicleId,
        'type': type.value,
        'numero': number,
        'date_expiration': expiresOn.toIso8601String().substring(0, 10),
        'updated_at': updatedAt.toIso8601String(),
      };
}
