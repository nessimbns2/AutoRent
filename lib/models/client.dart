class Client {
  final int? id;
  final String lastName;
  final String firstName;
  final String phone;
  final String? email;
  final String licenseNumber;
  final DateTime createdAt;

  const Client({
    this.id,
    required this.lastName,
    required this.firstName,
    required this.phone,
    this.email,
    required this.licenseNumber,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  factory Client.fromMap(Map<String, Object?> m) => Client(
        id: m['id'] as int?,
        lastName: m['nom'] as String,
        firstName: m['prenom'] as String,
        phone: m['telephone'] as String,
        email: m['email'] as String?,
        licenseNumber: m['numero_permis'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'nom': lastName,
        'prenom': firstName,
        'telephone': phone,
        if (email != null) 'email': email,
        'numero_permis': licenseNumber,
        'created_at': createdAt.toIso8601String(),
      };

  Client copyWith({
    int? id,
    String? lastName,
    String? firstName,
    String? phone,
    String? email,
    String? licenseNumber,
    DateTime? createdAt,
    bool clearEmail = false,
  }) =>
      Client(
        id: id ?? this.id,
        lastName: lastName ?? this.lastName,
        firstName: firstName ?? this.firstName,
        phone: phone ?? this.phone,
        email: clearEmail ? null : (email ?? this.email),
        licenseNumber: licenseNumber ?? this.licenseNumber,
        createdAt: createdAt ?? this.createdAt,
      );
}
