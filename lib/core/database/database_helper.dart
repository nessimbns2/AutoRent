import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'demo_data.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'autorent.db';

  /// v1: initial schema + demo data
  /// v2: new demo fleet (6 photographed cars) with rentals, maintenance and
  ///     incidents — replaces the previous vehicles and rentals.
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
    await DemoData.seedAccounts(db);
    await DemoData.seedFleet(db);
  }

  Future<void> _onUpgrade(Database db, int oldV, int newV) async {
    if (oldV < 2) {
      // Replace every vehicle, rental, maintenance and incident by the new
      // demo fleet. Users and clients are kept (missing demo clients added).
      await DemoData.resetFleet(db);
      await DemoData.seedAccounts(db);
      await DemoData.seedFleet(db);
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Full path of the SQLite file on this device.
  Future<String> get filePath async => join(await getDatabasesPath(), _dbName);

  /// Number of rows per business table (shown in the Profil tab).
  Future<Map<String, int>> tableCounts() async {
    final db = await database;
    const tables = [
      'users', 'clients', 'vehicles', 'vehicle_photos',
      'maintenances', 'rentals', 'incidents', 'incident_photos',
    ];
    return {
      for (final t in tables)
        t: Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $t')) ?? 0
    };
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

}
