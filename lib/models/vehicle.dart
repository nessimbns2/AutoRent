/// Vehicle category (stored as [value] in `vehicles.categorie`).
enum VehicleCategory {
  citadine('citadine', 'Citadine'),
  compacte('compacte', 'Compacte'),
  berline('berline', 'Berline'),
  suv('suv', 'SUV'),
  utilitaire('utilitaire', 'Utilitaire'),
  luxe('luxe', 'Luxe');

  const VehicleCategory(this.value, this.label);
  final String value;
  final String label;

  static VehicleCategory? fromValue(String? v) =>
      VehicleCategory.values.where((e) => e.value == v).firstOrNull;
}

/// Fuel / energy (stored as [value] in `vehicles.carburant`).
enum FuelType {
  essence('essence', 'Essence'),
  diesel('diesel', 'Diesel'),
  hybride('hybride', 'Hybride'),
  electrique('electrique', 'Électrique');

  const FuelType(this.value, this.label);
  final String value;
  final String label;

  static FuelType? fromValue(String? v) =>
      FuelType.values.where((e) => e.value == v).firstOrNull;
}

/// Gearbox (stored as [value] in `vehicles.boite`).
enum Gearbox {
  manuelle('manuelle', 'Manuelle'),
  automatique('automatique', 'Automatique');

  const Gearbox(this.value, this.label);
  final String value;
  final String label;

  static Gearbox? fromValue(String? v) =>
      Gearbox.values.where((e) => e.value == v).firstOrNull;
}

class Vehicle {
  final int? id;
  final String brand;
  final String model;
  final String plate;
  final double pricePerDay;
  final bool available;
  final DateTime createdAt;
  final List<String> photos; // file names only — the first one is the cover

  // Technical sheet (database v8) — all optional for older records.
  final VehicleCategory? category;
  final FuelType? fuel;
  final Gearbox? gearbox;
  final int? seats;
  final int? year;
  final String? color;
  final int? mileage;

  /// Retired from the fleet: hidden from lists, kept for the history.
  final bool archived;
  final DateTime? archivedAt;

  const Vehicle({
    this.id,
    required this.brand,
    required this.model,
    required this.plate,
    required this.pricePerDay,
    this.available = true,
    required this.createdAt,
    this.photos = const [],
    this.category,
    this.fuel,
    this.gearbox,
    this.seats,
    this.year,
    this.color,
    this.mileage,
    this.archived = false,
    this.archivedAt,
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
        category: VehicleCategory.fromValue(m['categorie'] as String?),
        fuel: FuelType.fromValue(m['carburant'] as String?),
        gearbox: Gearbox.fromValue(m['boite'] as String?),
        seats: m['places'] as int?,
        year: m['annee'] as int?,
        color: m['couleur'] as String?,
        mileage: m['kilometrage'] as int?,
        archived: (m['archive'] as int? ?? 0) == 1,
        archivedAt: m['archived_at'] == null
            ? null
            : DateTime.parse(m['archived_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'marque': brand,
        'modele': model,
        'immatriculation': plate,
        'prix_par_jour': pricePerDay,
        'disponible': available ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'categorie': category?.value,
        'carburant': fuel?.value,
        'boite': gearbox?.value,
        'places': seats,
        'annee': year,
        'couleur': color,
        'kilometrage': mileage,
        'archive': archived ? 1 : 0,
        'archived_at': archivedAt?.toIso8601String(),
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
    VehicleCategory? category,
    FuelType? fuel,
    Gearbox? gearbox,
    int? seats,
    int? year,
    String? color,
    int? mileage,
    bool? archived,
    DateTime? archivedAt,
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
        category: category ?? this.category,
        fuel: fuel ?? this.fuel,
        gearbox: gearbox ?? this.gearbox,
        seats: seats ?? this.seats,
        year: year ?? this.year,
        color: color ?? this.color,
        mileage: mileage ?? this.mileage,
        archived: archived ?? this.archived,
        archivedAt: archivedAt ?? this.archivedAt,
      );
}
