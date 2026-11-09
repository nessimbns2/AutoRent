import 'package:sqflite/sqflite.dart';

/// Database pieces of the "Incidents et pannes" module: the status history
/// table and the map position columns. Every step is idempotent so it can run
/// on any older database (main or incident branch) without failing.
class IncidentSchema {
  IncidentSchema._();

  /// One row per status change of an incident. `from_statut` is NULL for the
  /// declaration itself.
  static Future<void> createHistory(DatabaseExecutor db) async {
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

  /// Optional map position of an incident (latitude / longitude columns).
  static Future<void> addCoordinates(DatabaseExecutor db) async {
    final cols = {
      for (final r in await db.rawQuery('PRAGMA table_info(incidents)'))
        r['name'] as String,
    };
    if (!cols.contains('latitude')) {
      await db.execute('ALTER TABLE incidents ADD COLUMN latitude REAL');
    }
    if (!cols.contains('longitude')) {
      await db.execute('ALTER TABLE incidents ADD COLUMN longitude REAL');
    }
  }

  /// Gives every incident without history a "declared" entry (current status,
  /// declaring user, creation time) so older data shows up in the follow-up.
  static Future<void> backfillHistory(DatabaseExecutor db) async {
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

  /// True on a database from the incident branch before the merge with main
  /// (it already had the history table but still the old demo fleet).
  static Future<bool> hasHistoryTable(DatabaseExecutor db) async {
    final r = await db.rawQuery(
      "SELECT 1 FROM sqlite_master WHERE type = 'table' "
      "AND name = 'incident_history'",
    );
    return r.isNotEmpty;
  }
}
