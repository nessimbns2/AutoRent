class User {
  final int? id;
  final String lastName;
  final String firstName;
  final String email;
  final String passwordHash;
  final String? photoFile;
  final DateTime createdAt;

  const User({
    this.id,
    required this.lastName,
    required this.firstName,
    required this.email,
    required this.passwordHash,
    this.photoFile,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return '$f$l';
  }

  factory User.fromMap(Map<String, Object?> m) => User(
        id: m['id'] as int?,
        lastName: m['nom'] as String,
        firstName: m['prenom'] as String,
        email: m['email'] as String,
        passwordHash: m['password_hash'] as String,
        photoFile: m['photo_file'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'nom': lastName,
        'prenom': firstName,
        'email': email,
        'password_hash': passwordHash,
        if (photoFile != null) 'photo_file': photoFile,
        'created_at': createdAt.toIso8601String(),
      };

  User copyWith({
    int? id,
    String? lastName,
    String? firstName,
    String? email,
    String? passwordHash,
    String? photoFile,
    DateTime? createdAt,
    bool clearPhoto = false,
  }) =>
      User(
        id: id ?? this.id,
        lastName: lastName ?? this.lastName,
        firstName: firstName ?? this.firstName,
        email: email ?? this.email,
        passwordHash: passwordHash ?? this.passwordHash,
        photoFile: clearPhoto ? null : (photoFile ?? this.photoFile),
        createdAt: createdAt ?? this.createdAt,
      );
}
