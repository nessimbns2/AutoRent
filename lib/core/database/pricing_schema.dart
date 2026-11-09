import 'package:sqflite/sqflite.dart';

/// Database v9 — pricing grid: long-stay discounts, high season and
/// weekend rate. A single row (id = 1) edited from Profil → Grille tarifaire.
class PricingSchema {
  PricingSchema._();

  static const table = '''
    CREATE TABLE IF NOT EXISTS pricing_settings (
      id                  INTEGER PRIMARY KEY CHECK (id = 1),
      longue_duree        INTEGER NOT NULL DEFAULT 1 CHECK (longue_duree IN (0,1)),
      palier1_jours       INTEGER NOT NULL DEFAULT 7  CHECK (palier1_jours >= 2),
      palier1_remise      REAL    NOT NULL DEFAULT 10 CHECK (palier1_remise BETWEEN 0 AND 90),
      palier2_jours       INTEGER NOT NULL DEFAULT 30,
      palier2_remise      REAL    NOT NULL DEFAULT 25 CHECK (palier2_remise BETWEEN 0 AND 90),
      haute_saison        INTEGER NOT NULL DEFAULT 1 CHECK (haute_saison IN (0,1)),
      saison_debut        TEXT    NOT NULL DEFAULT '07-01',
      saison_fin          TEXT    NOT NULL DEFAULT '08-31',
      saison_majoration   REAL    NOT NULL DEFAULT 20 CHECK (saison_majoration BETWEEN 0 AND 100),
      week_end            INTEGER NOT NULL DEFAULT 1 CHECK (week_end IN (0,1)),
      week_end_majoration REAL    NOT NULL DEFAULT 10 CHECK (week_end_majoration BETWEEN -50 AND 100),
      updated_at          TEXT    NOT NULL,
      CHECK (palier2_jours > palier1_jours)
    )
  ''';

  /// Creates the table (new install or upgrade) with the default grid.
  static Future<void> migrate(DatabaseExecutor db) async {
    await db.execute(table);
    await db.rawInsert(
      'INSERT OR IGNORE INTO pricing_settings (id, updated_at) VALUES (1, ?)',
      [DateTime.now().toIso8601String()],
    );
  }
}
