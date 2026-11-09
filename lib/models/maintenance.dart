import 'enums.dart';

class Maintenance {
  final int? id;
  final int vehicleId;
  final String type;
  final DateTime date;
  final String? description;
  final MaintenanceStatus status;
  final DateTime createdAt;

  const Maintenance({
    this.id,
    required this.vehicleId,
    required this.type,
    required this.date,
    this.description,
    required this.status,
    required this.createdAt,
  });

  factory Maintenance.fromMap(Map<String, Object?> m) => Maintenance(
        id: m['id'] as int?,
        vehicleId: m['vehicle_id'] as int,
        type: m['type'] as String,
        date: DateTime.parse(m['date'] as String),
        description: m['description'] as String?,
        status: MaintenanceStatus.fromValue(m['statut'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'vehicle_id': vehicleId,
        'type': type,
        'date': date.toIso8601String().substring(0, 10),
        if (description != null) 'description': description,
        'statut': status.value,
        'created_at': createdAt.toIso8601String(),
      };

  Maintenance copyWith({
    int? id,
    int? vehicleId,
    String? type,
    DateTime? date,
    String? description,
    MaintenanceStatus? status,
    DateTime? createdAt,
    bool clearDescription = false,
  }) =>
      Maintenance(
        id: id ?? this.id,
        vehicleId: vehicleId ?? this.vehicleId,
        type: type ?? this.type,
        date: date ?? this.date,
        description: clearDescription ? null : (description ?? this.description),
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );
}

class MaintenanceView {
  final Maintenance maintenance;
  final String vehicleLabel;
  const MaintenanceView({required this.maintenance, required this.vehicleLabel});
}
