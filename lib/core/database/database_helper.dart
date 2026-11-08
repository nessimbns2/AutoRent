import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/services/password_hasher.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'autorent.db';

  /// v2: adds `incident_history` (status changes of incidents: who / when).
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    for (final stmt in _schemaStatements) {
      await db.execute(stmt);
    }
    await createIncidentHistory(db);
    await _seed(db);
    await backfillIncidentHistory(db);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      await createIncidentHistory(db);
      await backfillIncidentHistory(db);
    }
  }

  /// Schema v2 — one row per status change of an incident. `from_statut` is
  /// NULL for the declaration itself.
  static Future<void> createIncidentHistory(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS incident_history (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        incident_id        INTEGER NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
        from_statut        TEXT CHECK (from_statut IN ('en_attente','en_cours','resolu')),
        to_statut          TEXT NOT NULL CHECK (to_statut IN ('en_attente','en_cours','resolu')),
        changed_by_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
        changed_at         TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_incident_history_incident '
      'ON incident_history(incident_id, changed_at)',
    );
  }

  /// Gives every incident without history a "declared" entry (current status,
  /// declaring user, creation time) so old data shows up in the follow-up.
  static Future<void> backfillIncidentHistory(DatabaseExecutor db) async {
    await db.execute('''
      INSERT INTO incident_history
        (incident_id, from_statut, to_statut, changed_by_user_id, changed_at)
      SELECT i.id, NULL, i.statut, i.reported_by_user_id, i.created_at
      FROM incidents i
      WHERE NOT EXISTS (
        SELECT 1 FROM incident_history h WHERE h.incident_id = i.id
      )
    ''');
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  // ── Schema ──────────────────────────────────────────────────────────────────

  static const _schemaStatements = <String>[
    '''
    CREATE TABLE users (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      nom           TEXT NOT NULL,
      prenom        TEXT NOT NULL,
      email         TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      photo_file    TEXT,
      created_at    TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE clients (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      nom           TEXT NOT NULL,
      prenom        TEXT NOT NULL,
      telephone     TEXT NOT NULL,
      email         TEXT,
      numero_permis TEXT NOT NULL,
      created_at    TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE vehicles (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      marque          TEXT NOT NULL,
      modele          TEXT NOT NULL,
      immatriculation TEXT NOT NULL UNIQUE,
      prix_par_jour   REAL NOT NULL CHECK (prix_par_jour > 0),
      disponible      INTEGER NOT NULL DEFAULT 1 CHECK (disponible IN (0,1)),
      created_at      TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE vehicle_photos (
      id         INTEGER PRIMARY KEY AUTOINCREMENT,
      vehicle_id INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
      file_name  TEXT NOT NULL,
      position   INTEGER NOT NULL DEFAULT 0
    )
    ''',
    'CREATE INDEX idx_vehicle_photos_vehicle ON vehicle_photos(vehicle_id)',
    '''
    CREATE TABLE maintenances (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      vehicle_id  INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
      type        TEXT NOT NULL,
      date        TEXT NOT NULL,
      description TEXT,
      statut      TEXT NOT NULL DEFAULT 'planifie'
                  CHECK (statut IN ('planifie','en_cours','termine')),
      created_at  TEXT NOT NULL
    )
    ''',
    'CREATE INDEX idx_maintenances_vehicle ON maintenances(vehicle_id)',
    '''
    CREATE TABLE rentals (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      client_id   INTEGER NOT NULL REFERENCES clients(id)  ON DELETE RESTRICT,
      vehicle_id  INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
      user_id     INTEGER REFERENCES users(id) ON DELETE SET NULL,
      date_debut  TEXT NOT NULL,
      date_fin    TEXT NOT NULL,
      prix_total  REAL NOT NULL,
      statut      TEXT NOT NULL DEFAULT 'reservee'
                  CHECK (statut IN ('reservee','en_cours','terminee','annulee')),
      created_at  TEXT NOT NULL,
      CHECK (date_fin >= date_debut)
    )
    ''',
    'CREATE INDEX idx_rentals_vehicle ON rentals(vehicle_id, date_debut, date_fin)',
    'CREATE INDEX idx_rentals_client  ON rentals(client_id)',
    '''
    CREATE TABLE incidents (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      vehicle_id          INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
      rental_id           INTEGER REFERENCES rentals(id) ON DELETE SET NULL,
      reported_by_user_id INTEGER REFERENCES users(id) ON DELETE SET NULL,
      type                TEXT NOT NULL CHECK (type IN ('accident','panne')),
      date                TEXT NOT NULL,
      lieu                TEXT NOT NULL,
      description         TEXT NOT NULL,
      statut              TEXT NOT NULL DEFAULT 'en_attente'
                          CHECK (statut IN ('en_attente','en_cours','resolu')),
      created_at          TEXT NOT NULL
    )
    ''',
    'CREATE INDEX idx_incidents_vehicle ON incidents(vehicle_id)',
    '''
    CREATE TABLE incident_photos (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      incident_id INTEGER NOT NULL REFERENCES incidents(id) ON DELETE CASCADE,
      file_name   TEXT NOT NULL,
      position    INTEGER NOT NULL DEFAULT 0
    )
    ''',
    'CREATE INDEX idx_incident_photos_incident ON incident_photos(incident_id)',
  ];

  // ── Seed ────────────────────────────────────────────────────────────────────

  Future<void> _seed(Database db) async {
    final now = DateTime.now();
    final ts = now.toIso8601String();

    // Users
    final adminHash = PasswordHasher.hash('Admin123!');
    final agentHash = PasswordHasher.hash('Agent123!');
    final adminId = await db.insert('users', {
      'nom': 'Administrateur',
      'prenom': 'AutoRent',
      'email': 'admin@autorent.tn',
      'password_hash': adminHash,
      'created_at': ts,
    });
    final agentId = await db.insert('users', {
      'nom': 'Ben Ali',
      'prenom': 'Sami',
      'email': 'agent@autorent.tn',
      'password_hash': agentHash,
      'created_at': ts,
    });

    // Clients
    final client1 = await db.insert('clients', {
      'nom': 'Hamdi',
      'prenom': 'Rania',
      'telephone': '22334455',
      'email': 'rania@example.com',
      'numero_permis': 'P123456',
      'created_at': ts,
    });
    final client2 = await db.insert('clients', {
      'nom': 'Trabelsi',
      'prenom': 'Mohamed',
      'telephone': '55667788',
      'numero_permis': 'P789012',
      'created_at': ts,
    });
    final client3 = await db.insert('clients', {
      'nom': 'Bouzid',
      'prenom': 'Leila',
      'telephone': '98765432',
      'email': 'leila.bouzid@example.com',
      'numero_permis': 'P345678',
      'created_at': ts,
    });

    // Vehicles (5)
    final v1 = await db.insert('vehicles', {
      'marque': 'Peugeot',
      'modele': '208',
      'immatriculation': '123 TUN 4567',
      'prix_par_jour': 80.0,
      'disponible': 1,
      'created_at': ts,
    });
    final v2 = await db.insert('vehicles', {
      'marque': 'Renault',
      'modele': 'Clio',
      'immatriculation': '456 TUN 1234',
      'prix_par_jour': 75.0,
      'disponible': 1,
      'created_at': ts,
    });
    final v3 = await db.insert('vehicles', {
      'marque': 'Toyota',
      'modele': 'Yaris',
      'immatriculation': '789 TUN 5678',
      'prix_par_jour': 90.0,
      'disponible': 1,
      'created_at': ts,
    });
    final v4 = await db.insert('vehicles', {
      'marque': 'Volkswagen',
      'modele': 'Golf',
      'immatriculation': '321 TUN 9876',
      'prix_par_jour': 100.0,
      'disponible': 1,
      'created_at': ts,
    });
    final v5 = await db.insert('vehicles', {
      'marque': 'Dacia',
      'modele': 'Logan',
      'immatriculation': '654 TUN 3210',
      'prix_par_jour': 60.0,
      'disponible': 0,
      'created_at': ts,
    });

    // Maintenances (3 — one per status)
    await db.insert('maintenances', {
      'vehicle_id': v1,
      'type': 'Vidange',
      'date': _isoDate(now.subtract(const Duration(days: 10))),
      'statut': 'termine',
      'created_at': ts,
    });
    await db.insert('maintenances', {
      'vehicle_id': v2,
      'type': 'Pneus',
      'date': _isoDate(now),
      'statut': 'en_cours',
      'description': 'Remplacement des pneus avant',
      'created_at': ts,
    });
    await db.insert('maintenances', {
      'vehicle_id': v3,
      'type': 'Révision',
      'date': _isoDate(now.add(const Duration(days: 5))),
      'statut': 'planifie',
      'description': 'Révision annuelle',
      'created_at': ts,
    });

    // Rentals (3 — reservee / en_cours / terminee)
    await db.insert('rentals', {
      'client_id': client1,
      'vehicle_id': v3,
      'user_id': adminId,
      'date_debut': _isoDate(now.add(const Duration(days: 3))),
      'date_fin': _isoDate(now.add(const Duration(days: 7))),
      'prix_total': 90.0 * 4,
      'statut': 'reservee',
      'created_at': ts,
    });
    final r2 = await db.insert('rentals', {
      'client_id': client2,
      'vehicle_id': v4,
      'user_id': agentId,
      'date_debut': _isoDate(now.subtract(const Duration(days: 2))),
      'date_fin': _isoDate(now.add(const Duration(days: 3))),
      'prix_total': 100.0 * 5,
      'statut': 'en_cours',
      'created_at': ts,
    });
    await db.insert('rentals', {
      'client_id': client3,
      'vehicle_id': v1,
      'user_id': adminId,
      'date_debut': _isoDate(now.subtract(const Duration(days: 14))),
      'date_fin': _isoDate(now.subtract(const Duration(days: 10))),
      'prix_total': 80.0 * 4,
      'statut': 'terminee',
      'created_at': ts,
    });

    // Incidents (7) — every status and type, each with its status history
    // (who changed what, and when) so the follow-up dashboard has data.
    DateTime ago(int days, [int hour = 9, int minute = 0]) {
      final d = now.subtract(Duration(days: days));
      return DateTime(d.year, d.month, d.day, hour, minute);
    }

    Future<void> incident({
      required int vehicleId,
      int? rentalId,
      required int reportedBy,
      required String type,
      required int daysAgo,
      required String lieu,
      required String description,
      required List<(String statut, int userId, DateTime at)> history,
    }) async {
      final id = await db.insert('incidents', {
        'vehicle_id': vehicleId,
        'rental_id': rentalId,
        'reported_by_user_id': reportedBy,
        'type': type,
        'date': _isoDate(now.subtract(Duration(days: daysAgo))),
        'lieu': lieu,
        'description': description,
        'statut': history.last.$1,
        'created_at': history.first.$3.toIso8601String(),
      });
      String? from;
      for (final (statut, userId, at) in history) {
        await db.insert('incident_history', {
          'incident_id': id,
          'from_statut': from,
          'to_statut': statut,
          'changed_by_user_id': userId,
          'changed_at': at.toIso8601String(),
        });
        from = statut;
      }
    }

    await incident(
      vehicleId: v1,
      reportedBy: agentId,
      type: 'accident',
      daysAgo: 12,
      lieu: 'Tunis centre',
      description: 'Accrochage léger en parking. Pare-choc avant endommagé.',
      history: [('en_attente', agentId, ago(12, 10, 15))],
    );
    await incident(
      vehicleId: v4,
      rentalId: r2,
      reportedBy: adminId,
      type: 'panne',
      daysAgo: 1,
      lieu: 'Autoroute A1 km 54',
      description: "Crevaison lors d'un trajet. Roue de secours montée.",
      history: [
        ('en_attente', adminId, ago(1, 8, 40)),
        ('en_cours', agentId, ago(1, 9, 5)),
        ('resolu', agentId, ago(1, 14, 30)),
      ],
    );
    await incident(
      vehicleId: v2,
      reportedBy: agentId,
      type: 'panne',
      daysAgo: 3,
      lieu: 'Parking Lac 2, Tunis',
      description:
          'Le véhicule ne démarre plus, batterie à plat. Dépanneuse appelée.',
      history: [
        ('en_attente', agentId, ago(3, 9, 10)),
        ('en_cours', adminId, ago(3, 11, 30)),
      ],
    );
    await incident(
      vehicleId: v1,
      reportedBy: agentId,
      type: 'accident',
      daysAgo: 11,
      lieu: 'Avenue Habib Bourguiba, Tunis',
      description: 'Choc arrière à un feu rouge. Feu arrière gauche cassé, constat amiable rempli.',
      history: [
        ('en_attente', agentId, ago(11, 17, 20)),
        ('en_cours', adminId, ago(10, 9, 0)),
        ('resolu', adminId, ago(6, 16, 45)),
      ],
    );
    await incident(
      vehicleId: v3,
      reportedBy: adminId,
      type: 'panne',
      daysAgo: 1,
      lieu: 'Route de la Marsa',
      description: 'Voyant moteur allumé et perte de puissance en côte.',
      history: [('en_attente', adminId, ago(1, 18, 5))],
    );
    await incident(
      vehicleId: v4,
      rentalId: r2,
      reportedBy: agentId,
      type: 'accident',
      daysAgo: 0,
      lieu: 'Sousse, zone touristique',
      description: 'Rayure profonde sur la portière arrière droite, constatée au retour du parking.',
      history: [
        ('en_attente', agentId, ago(0, 8, 30)),
        ('en_cours', agentId, ago(0, 8, 50)),
      ],
    );
    await incident(
      vehicleId: v5,
      reportedBy: adminId,
      type: 'panne',
      daysAgo: 20,
      lieu: 'Autoroute A1, sortie Hammamet',
      description:
          'Pneu avant gauche éclaté. Remorquage jusqu\'au garage partenaire.',
      history: [
        ('en_attente', adminId, ago(20, 7, 45)),
        ('en_cours', agentId, ago(20, 9, 15)),
        ('resolu', agentId, ago(19, 12, 0)),
      ],
    );
  }

  static String _isoDate(DateTime d) => d.toIso8601String().substring(0, 10);
}
