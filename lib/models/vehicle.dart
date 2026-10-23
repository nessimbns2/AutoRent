class Vehicle {
  final int? id;
  final String brand;
  final String model;
  final String plate;
  final double pricePerDay;
  final bool available;
  final DateTime createdAt;
  final List<String> photos; // file names only

  const Vehicle({
    this.id,
    required this.brand,
    required this.model,
    required this.plate,
    required this.pricePerDay,
    this.available = true,
    required this.createdAt,
    this.photos = const [],
  });

  /// Human-readable label used in dropdowns and list items.
  String get label => '$brand $model · $plate';

  factory Vehicle.fromMap(Map<String, Object?> m,
          {List<String> photos = const []}) =>
      Vehicle(
        id: m['id'] as int?,
        brand: m['marque'] as String,
        model: m['modele'] as String,
        plate: m['immatriculation'] as String,
        pricePerDay: (m['prix_par_jour'] as num).toDouble(),
        available: (m['disponible'] as int) == 1,
        createdAt: DateTime.parse(m['created_at'] as String),
        photos: photos,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'marque': brand,
        'modele': model,
        'immatriculation': plate,
        'prix_par_jour': pricePerDay,
        'disponible': available ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  Vehicle copyWith({
    int? id,
    String? brand,
    String? model,
    String? plate,
    double? pricePerDay,
    bool? available,
    DateTime? createdAt,
    List<String>? photos,
  }) =>
      Vehicle(
        id: id ?? this.id,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        plate: plate ?? this.plate,
        pricePerDay: pricePerDay ?? this.pricePerDay,
        available: available ?? this.available,
        createdAt: createdAt ?? this.createdAt,
        photos: photos ?? this.photos,
      );
}
