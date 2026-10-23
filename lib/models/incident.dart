import 'enums.dart';

class Incident {
  final int? id;
  final int vehicleId;
  final int? rentalId;
  final int? reportedByUserId;
  final IncidentType type;
  final DateTime date;
  final String place;
  final String description;
  final IncidentStatus status;
  final DateTime createdAt;
  final List<String> photos;

  const Incident({
    this.id,
    required this.vehicleId,
    this.rentalId,
    this.reportedByUserId,
    required this.type,
    required this.date,
    required this.place,
    required this.description,
    required this.status,
    required this.createdAt,
    this.photos = const [],
  });

  factory Incident.fromMap(Map<String, Object?> m,
          {List<String> photos = const []}) =>
      Incident(
        id: m['id'] as int?,
        vehicleId: m['vehicle_id'] as int,
        rentalId: m['rental_id'] as int?,
        reportedByUserId: m['reported_by_user_id'] as int?,
        type: IncidentType.fromValue(m['type'] as String),
        date: DateTime.parse(m['date'] as String),
        place: m['lieu'] as String,
        description: m['description'] as String,
        status: IncidentStatus.fromValue(m['statut'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
        photos: photos,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'vehicle_id': vehicleId,
        if (rentalId != null) 'rental_id': rentalId,
        if (reportedByUserId != null) 'reported_by_user_id': reportedByUserId,
        'type': type.value,
        'date': date.toIso8601String().substring(0, 10),
        'lieu': place,
        'description': description,
        'statut': status.value,
        'created_at': createdAt.toIso8601String(),
      };

  Incident copyWith({
    int? id,
    int? vehicleId,
    int? rentalId,
    int? reportedByUserId,
    IncidentType? type,
    DateTime? date,
    String? place,
    String? description,
    IncidentStatus? status,
    DateTime? createdAt,
    List<String>? photos,
  }) =>
      Incident(
        id: id ?? this.id,
        vehicleId: vehicleId ?? this.vehicleId,
        rentalId: rentalId ?? this.rentalId,
        reportedByUserId: reportedByUserId ?? this.reportedByUserId,
        type: type ?? this.type,
        date: date ?? this.date,
        place: place ?? this.place,
        description: description ?? this.description,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        photos: photos ?? this.photos,
      );
}

class IncidentView {
  final Incident incident;
  final String vehicleLabel;
  final String? reporterName;
  const IncidentView({
    required this.incident,
    required this.vehicleLabel,
    this.reporterName,
  });
}
