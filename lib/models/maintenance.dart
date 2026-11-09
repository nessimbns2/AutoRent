import 'enums.dart';

class Maintenance {
  final int? id;
  final int vehicleId;
  final String type;
  final DateTime date;
  final String? description;
  final MaintenanceStatus status;
  final DateTime createdAt;
  final double? costEstimated;
  final double? costActual;
  final int? mileage;
  final String? garage;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const Maintenance({
    this.id,
    required this.vehicleId,
    required this.type,
    required this.date,
    this.description,
    required this.status,
    required this.createdAt,
    this.costEstimated,
    this.costActual,
    this.mileage,
    this.garage,
    this.startedAt,
    this.endedAt,
  });

  factory Maintenance.fromMap(Map<String, Object?> m) => Maintenance(
        id: m['id'] as int?,
        vehicleId: m['vehicle_id'] as int,
        type: m['type'] as String,
        date: DateTime.parse(m['date'] as String),
        description: m['description'] as String?,
        status: MaintenanceStatus.fromValue(m['statut'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
        costEstimated: (m['cout_estime'] as num?)?.toDouble(),
        costActual: (m['cout_reel'] as num?)?.toDouble(),
        mileage: m['kilometrage'] as int?,
        garage: m['garage'] as String?,
        startedAt: m['started_at'] != null
            ? DateTime.parse(m['started_at'] as String)
            : null,
        endedAt: m['ended_at'] != null
            ? DateTime.parse(m['ended_at'] as String)
            : null,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'vehicle_id': vehicleId,
        'type': type,
        'date': date.toIso8601String().substring(0, 10),
        if (description != null) 'description': description,
        'statut': status.value,
        'created_at': createdAt.toIso8601String(),
        if (costEstimated != null) 'cout_estime': costEstimated,
        if (costActual != null) 'cout_reel': costActual,
        if (mileage != null) 'kilometrage': mileage,
        if (garage != null) 'garage': garage,
        if (startedAt != null) 'started_at': startedAt!.toIso8601String(),
        if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
      };

  Maintenance copyWith({
    int? id,
    int? vehicleId,
    String? type,
    DateTime? date,
    String? description,
    MaintenanceStatus? status,
    DateTime? createdAt,
    double? costEstimated,
    double? costActual,
    int? mileage,
    String? garage,
    DateTime? startedAt,
    DateTime? endedAt,
    bool clearDescription = false,
    bool clearCostEstimated = false,
    bool clearCostActual = false,
    bool clearMileage = false,
    bool clearGarage = false,
    bool clearStartedAt = false,
    bool clearEndedAt = false,
  }) =>
      Maintenance(
        id: id ?? this.id,
        vehicleId: vehicleId ?? this.vehicleId,
        type: type ?? this.type,
        date: date ?? this.date,
        description: clearDescription ? null : (description ?? this.description),
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        costEstimated: clearCostEstimated ? null : (costEstimated ?? this.costEstimated),
        costActual: clearCostActual ? null : (costActual ?? this.costActual),
        mileage: clearMileage ? null : (mileage ?? this.mileage),
        garage: clearGarage ? null : (garage ?? this.garage),
        startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
        endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      );
}

class MaintenanceView {
  final Maintenance maintenance;
  final String vehicleLabel;
  const MaintenanceView({required this.maintenance, required this.vehicleLabel});
}
