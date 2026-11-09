class User {
  final int? id;
  final String lastName;
  final String firstName;
  final String email;
  final String passwordHash;
  final String? photoFile;
  final DateTime createdAt;

  // Security fields (DB schema v2). They are read from the DB but are NOT part
  // of toMap(): they are only written through dedicated UserRepository methods,
  // so a stale in-memory User can never overwrite them by calling update().
  final String? recoveryKeyHash;
  final int failedAttempts;
  final DateTime? lockedUntil;
  final String? totpSecret; // base32 secret; null = 2FA off
  final int totpLastStep; // last accepted 30 s step (replay protection)

  const User({
    this.id,
    required this.lastName,
    required this.firstName,
    required this.email,
    required this.passwordHash,
    this.photoFile,
    required this.createdAt,
    this.recoveryKeyHash,
    this.failedAttempts = 0,
    this.lockedUntil,
    this.totpSecret,
    this.totpLastStep = 0,
  });

  bool get totpEnabled => totpSecret != null;

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
        recoveryKeyHash: m['recovery_key_hash'] as String?,
        failedAttempts: (m['failed_attempts'] as int?) ?? 0,
        lockedUntil: m['locked_until'] == null
            ? null
            : DateTime.parse(m['locked_until'] as String),
        totpSecret: m['totp_secret'] as String?,
        totpLastStep: (m['totp_last_step'] as int?) ?? 0,
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
        recoveryKeyHash: recoveryKeyHash,
        failedAttempts: failedAttempts,
        lockedUntil: lockedUntil,
        totpSecret: totpSecret,
        totpLastStep: totpLastStep,
      );
}
