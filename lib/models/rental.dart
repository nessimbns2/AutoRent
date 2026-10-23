import 'enums.dart';

class Rental {
  final int? id;
  final int clientId;
  final int vehicleId;
  final int? userId;
  final DateTime startDate;
  final DateTime endDate;
  final double totalPrice;
  final RentalStatus status;
  final DateTime createdAt;

  const Rental({
    this.id,
    required this.clientId,
    required this.vehicleId,
    this.userId,
    required this.startDate,
    required this.endDate,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
  });

  int get days {
    final d = endDate.difference(startDate).inDays;
    return d < 1 ? 1 : d;
  }

  factory Rental.fromMap(Map<String, Object?> m) => Rental(
        id: m['id'] as int?,
        clientId: m['client_id'] as int,
        vehicleId: m['vehicle_id'] as int,
        userId: m['user_id'] as int?,
        startDate: DateTime.parse(m['date_debut'] as String),
        endDate: DateTime.parse(m['date_fin'] as String),
        totalPrice: (m['prix_total'] as num).toDouble(),
        status: RentalStatus.fromValue(m['statut'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'client_id': clientId,
        'vehicle_id': vehicleId,
        if (userId != null) 'user_id': userId,
        'date_debut': startDate.toIso8601String().substring(0, 10),
        'date_fin': endDate.toIso8601String().substring(0, 10),
        'prix_total': totalPrice,
        'statut': status.value,
        'created_at': createdAt.toIso8601String(),
      };

  Rental copyWith({
    int? id,
    int? clientId,
    int? vehicleId,
    int? userId,
    DateTime? startDate,
    DateTime? endDate,
    double? totalPrice,
    RentalStatus? status,
    DateTime? createdAt,
  }) =>
      Rental(
        id: id ?? this.id,
        clientId: clientId ?? this.clientId,
        vehicleId: vehicleId ?? this.vehicleId,
        userId: userId ?? this.userId,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        totalPrice: totalPrice ?? this.totalPrice,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
      );
}

class RentalView {
  final Rental rental;
  final String clientName;
  final String vehicleLabel;
  final String? userName;
  const RentalView({
    required this.rental,
    required this.clientName,
    required this.vehicleLabel,
    this.userName,
  });
}
