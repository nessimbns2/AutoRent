import 'package:sqflite/sqflite.dart';

/// Database v8 — vehicle module: technical sheet, archiving and
/// administrative documents (insurance, roadworthiness test, road tax,
/// registration) with their expiry dates.
class VehicleSchema {
  VehicleSchema._();

  /// Columns added to `vehicles` (also present in the CREATE TABLE of new
  /// installs, so "duplicate column" errors are ignored on upgrade).
  static const _columns = <String>[
    'ALTER TABLE vehicles ADD COLUMN categorie TEXT',
    'ALTER TABLE vehicles ADD COLUMN carburant TEXT',
    'ALTER TABLE vehicles ADD COLUMN boite TEXT',
    'ALTER TABLE vehicles ADD COLUMN places INTEGER',
    'ALTER TABLE vehicles ADD COLUMN annee INTEGER',
    'ALTER TABLE vehicles ADD COLUMN couleur TEXT',
    'ALTER TABLE vehicles ADD COLUMN kilometrage INTEGER',
    'ALTER TABLE vehicles ADD COLUMN archive INTEGER NOT NULL DEFAULT 0',
    'ALTER TABLE vehicles ADD COLUMN archived_at TEXT',
  ];

  static const documentsTable = '''
    CREATE TABLE IF NOT EXISTS vehicle_documents (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      vehicle_id      INTEGER NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
      type            TEXT NOT NULL
                      CHECK (type IN ('assurance','visite_technique','vignette','carte_grise')),
      numero          TEXT,
      date_expiration TEXT NOT NULL,
      updated_at      TEXT NOT NULL,
      UNIQUE (vehicle_id, type)
    )
  ''';

  static const documentsIndex =
      'CREATE INDEX IF NOT EXISTS idx_vehicle_documents_expiry '
      'ON vehicle_documents(date_expiration)';

  /// Upgrade of an existing database to v8.
  static Future<void> migrate(DatabaseExecutor db) async {
    for (final stmt in _columns) {
      try {
        await db.execute(stmt);
      } catch (_) {
        // Column already exists — safe to ignore.
      }
    }
    await db.execute(documentsTable);
    await db.execute(documentsIndex);
  }

  static String _iso(DateTime d) => d.toIso8601String().substring(0, 10);

  /// Technical sheet + documents of the 6 demo cars (matched by plate, only
  /// filled when empty, so it never overwrites the agency's own data).
  /// Some documents are expired or about to expire on purpose to showcase
  /// the alerts and the "no rental with expired insurance" rule.
  static Future<void> seedDemoDetails(DatabaseExecutor db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime day(int offset) => today.add(Duration(days: offset));

    // plate: (catégorie, carburant, boîte, places, année, couleur, km,
    //         assurance, visite technique, vignette, carte grise) in days
    const demo = <String, (String, String, String, int, int, String, int,
        int, int, int, int)>{
      '128 TUN 4521': ('citadine', 'essence', 'manuelle', 5, 2024,
          'Gris argent', 18450, 210, -2, 140, 2900),
      '215 TUN 7834': ('compacte', 'essence', 'automatique', 5, 2023, 'Rouge',
          27300, 5, 300, 140, 2500),
      '187 TUN 3390': ('berline', 'diesel', 'manuelle', 5, 2023, 'Noir',
          41200, 150, 240, 25, 2400),
      '231 TUN 1056': ('citadine', 'essence', 'manuelle', 5, 2022, 'Bleu',
          52800, 60, 12, 140, 2100),
      '176 TUN 8812': ('citadine', 'diesel', 'manuelle', 5, 2019, 'Rouge',
          96500, 90, 180, 140, 1000),
      '240 TUN 2468': ('suv', 'hybride', 'automatique', 5, 2025, 'Vert',
          8900, 330, 700, 140, 3300),
    };

    final ts = now.toIso8601String();
    for (final e in demo.entries) {
      final rows = await db.query('vehicles',
          columns: ['id'], where: 'immatriculation = ?', whereArgs: [e.key]);
      if (rows.isEmpty) continue;
      final id = rows.first['id'] as int;
      final (cat, fuel, box, seats, year, color, km, ins, vt, vig, cg) =
          e.value;
      await db.rawUpdate('''
        UPDATE vehicles SET
          categorie   = COALESCE(categorie, ?),
          carburant   = COALESCE(carburant, ?),
          boite       = COALESCE(boite, ?),
          places      = COALESCE(places, ?),
          annee       = COALESCE(annee, ?),
          couleur     = COALESCE(couleur, ?),
          kilometrage = COALESCE(kilometrage, ?)
        WHERE id = ?
      ''', [cat, fuel, box, seats, year, color, km, id]);

      for (final (type, offset, number) in [
        ('assurance', ins, 'POL-${now.year}-${id.toString().padLeft(4, '0')}'),
        ('visite_technique', vt, 'VT-${id.toString().padLeft(5, '0')}'),
        ('vignette', vig, null),
        ('carte_grise', cg, e.key.replaceAll(' ', '')),
      ]) {
        await db.rawInsert(
          'INSERT OR IGNORE INTO vehicle_documents '
          '(vehicle_id, type, numero, date_expiration, updated_at) '
          'VALUES (?, ?, ?, ?, ?)',
          [id, type, number, _iso(day(offset)), ts],
        );
      }
    }
  }
}
