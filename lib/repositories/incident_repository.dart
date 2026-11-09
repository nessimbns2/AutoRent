import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/services/image_storage.dart';
import '../core/utils/app_exception.dart';
import '../models/enums.dart';
import '../models/incident.dart';
import '../models/incident_stats.dart';

class IncidentRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  /// Incident joined with its vehicle, the declaring user and, when linked,
  /// the renter (client) of the rental.
  static const _viewSelect = '''
      SELECT i.*,
             v.marque || ' ' || v.modele || ' · ' || v.immatriculation AS vehicle_label,
             u.nom || ' ' || u.prenom AS reporter_name,
             c.nom || ' ' || c.prenom AS client_name
      FROM incidents i
      JOIN vehicles v ON v.id = i.vehicle_id
      LEFT JOIN users u ON u.id = i.reported_by_user_id
      LEFT JOIN rentals r ON r.id = i.rental_id
      LEFT JOIN clients c ON c.id = r.client_id
  ''';

  Future<IncidentView> _toView(Map<String, Object?> r) async => IncidentView(
    incident: Incident.fromMap(r, photos: await getPhotos(r['id'] as int)),
    vehicleLabel: r['vehicle_label'] as String,
    reporterName: r['reporter_name'] as String?,
    clientName: r['client_name'] as String?,
  );

  /// Lists incidents, newest first, optionally filtered by [status], [type]
  /// and a free-text [query] matched against the vehicle (brand, model,
  /// plate), the place, the description and the renter's name.
  Future<List<IncidentView>> getViews({
    IncidentStatus? status,
    IncidentType? type,
    String query = '',
  }) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (status != null) {
      where.add('i.statut = ?');
      args.add(status.value);
    }
    if (type != null) {
      where.add('i.type = ?');
      args.add(type.value);
    }
    final q = query.trim();
    if (q.isNotEmpty) {
      final like =
          '%${q.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
      where.add('''(
        v.marque LIKE ? ESCAPE '\\' OR v.modele LIKE ? ESCAPE '\\'
        OR v.immatriculation LIKE ? ESCAPE '\\' OR i.lieu LIKE ? ESCAPE '\\'
        OR i.description LIKE ? ESCAPE '\\'
        OR (c.nom || ' ' || c.prenom) LIKE ? ESCAPE '\\'
        OR (c.prenom || ' ' || c.nom) LIKE ? ESCAPE '\\'
      )''');
      args.addAll(List.filled(7, like));
    }
    final rows = await db.rawQuery('''
      $_viewSelect
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY i.date DESC, i.id DESC
    ''', args);
    return [for (final r in rows) await _toView(r)];
  }

  Future<List<IncidentView>> getViewsByStatus(IncidentStatus status) =>
      getViews(status: status);

  /// Number of incidents per status, every status present (0 when none).
  Future<Map<IncidentStatus, int>> countByStatus() async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT statut, COUNT(*) AS n FROM incidents GROUP BY statut',
    );
    final counts = {for (final s in IncidentStatus.values) s: 0};
    for (final r in rows) {
      counts[IncidentStatus.fromValue(r['statut'] as String)] = r['n'] as int;
    }
    return counts;
  }

  /// Distinct places from the most recent incidents (for quick suggestions in
  /// the declaration form).
  Future<List<String>> recentPlaces({int limit = 6}) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT lieu, MAX(created_at) AS last_used
      FROM incidents
      WHERE TRIM(lieu) <> ''
      GROUP BY lieu COLLATE NOCASE
      ORDER BY last_used DESC
      LIMIT ?
    ''',
      [limit],
    );
    return [for (final r in rows) r['lieu'] as String];
  }

  Future<IncidentView?> getViewById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('$_viewSelect WHERE i.id = ?', [id]);
    if (rows.isEmpty) return null;
    return _toView(rows.first);
  }

  Future<Incident?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('incidents', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Incident.fromMap(rows.first, photos: await getPhotos(id));
  }

  Future<List<String>> getPhotos(int incidentId) async {
    final db = await _db;
    final rows = await db.query(
      'incident_photos',
      where: 'incident_id = ?',
      whereArgs: [incidentId],
      orderBy: 'position',
    );
    return [for (final r in rows) r['file_name'] as String];
  }

  /// Inserts the incident, its photos and the "declared" history entry.
  Future<int> insert(Incident inc) async {
    final db = await _db;
    return db.transaction((txn) async {
      final id = await txn.insert('incidents', inc.toMap());
      await _writePhotos(txn, id, inc.photos);
      await _logStatus(
        txn,
        id,
        from: null,
        to: inc.status,
        byUserId: inc.reportedByUserId,
        at: inc.createdAt,
      );
      return id;
    });
  }

  /// Updates the incident; a status change is recorded in the history,
  /// attributed to [byUserId] (the logged-in user).
  Future<void> update(Incident inc, {int? byUserId}) async {
    final db = await _db;
    await db.transaction((txn) async {
      final before = await _currentStatus(txn, inc.id!);
      await txn.update(
        'incidents',
        inc.toMap(),
        where: 'id = ?',
        whereArgs: [inc.id],
      );
      await _writePhotos(txn, inc.id!, inc.photos);
      if (before != null && before != inc.status) {
        await _logStatus(
          txn,
          inc.id!,
          from: before,
          to: inc.status,
          byUserId: byUserId,
        );
      }
    });
  }

  /// Changes the status and records who did it. No-op if unchanged.
  Future<void> changeStatus(
    int id,
    IncidentStatus status, {
    int? byUserId,
  }) async {
    final db = await _db;
    await db.transaction((txn) async {
      final before = await _currentStatus(txn, id);
      if (before == null || before == status) return;
      await txn.update(
        'incidents',
        {'statut': status.value},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _logStatus(txn, id, from: before, to: status, byUserId: byUserId);
    });
  }

  /// Status changes of one incident, oldest first.
  Future<List<IncidentHistoryEntry>> getHistory(int incidentId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT h.*, u.nom || ' ' || u.prenom AS user_name
      FROM incident_history h
      LEFT JOIN users u ON u.id = h.changed_by_user_id
      WHERE h.incident_id = ?
      ORDER BY h.changed_at, h.id
    ''',
      [incidentId],
    );
    return [for (final r in rows) IncidentHistoryEntry.fromMap(r)];
  }

  /// Figures for the follow-up dashboard. [now] is injectable for tests.
  Future<IncidentStats> getStats({DateTime? now}) async {
    final db = await _db;
    final byStatus = await countByStatus();

    final byType = {for (final t in IncidentType.values) t: 0};
    for (final r in await db.rawQuery(
      'SELECT type, COUNT(*) AS n FROM incidents GROUP BY type',
    )) {
      byType[IncidentType.fromValue(r['type'] as String)] = r['n'] as int;
    }

    final since = (now ?? DateTime.now())
        .subtract(const Duration(days: 30))
        .toIso8601String();
    final last30 =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM incidents WHERE created_at >= ?',
            [since],
          ),
        ) ??
        0;

    // Declaration → last switch to "résolu", for incidents resolved now.
    final avgRow = await db.rawQuery('''
      SELECT AVG(julianday(h.resolved_at) - julianday(i.created_at)) AS days
      FROM incidents i
      JOIN (
        SELECT incident_id, MAX(changed_at) AS resolved_at
        FROM incident_history WHERE to_statut = 'resolu'
        GROUP BY incident_id
      ) h ON h.incident_id = i.id
      WHERE i.statut = 'resolu'
    ''');
    final avgDays = avgRow.first['days'] as num?;

    final topRows = await db.rawQuery('''
      SELECT v.id AS vehicle_id,
             v.marque || ' ' || v.modele || ' · ' || v.immatriculation AS vehicle_label,
             COUNT(*) AS n
      FROM incidents i JOIN vehicles v ON v.id = i.vehicle_id
      GROUP BY v.id
      ORDER BY n DESC, vehicle_label
      LIMIT 3
    ''');

    final activityRows = await db.rawQuery('''
      SELECT h.*, u.nom || ' ' || u.prenom AS user_name, i.type,
             v.marque || ' ' || v.modele || ' · ' || v.immatriculation AS vehicle_label
      FROM incident_history h
      JOIN incidents i ON i.id = h.incident_id
      JOIN vehicles v ON v.id = i.vehicle_id
      LEFT JOIN users u ON u.id = h.changed_by_user_id
      ORDER BY h.changed_at DESC, h.id DESC
      LIMIT 8
    ''');

    return IncidentStats(
      byStatus: byStatus,
      byType: byType,
      last30Days: last30,
      averageResolution: avgDays == null
          ? null
          : Duration(minutes: (avgDays * 24 * 60).round()),
      topVehicles: [
        for (final r in topRows)
          VehicleIncidentCount(
            vehicleId: r['vehicle_id'] as int,
            vehicleLabel: r['vehicle_label'] as String,
            count: r['n'] as int,
          ),
      ],
      recentActivity: [
        for (final r in activityRows)
          IncidentActivity(
            entry: IncidentHistoryEntry.fromMap(r),
            type: IncidentType.fromValue(r['type'] as String),
            vehicleLabel: r['vehicle_label'] as String,
          ),
      ],
    );
  }

  Future<IncidentStatus?> _currentStatus(DatabaseExecutor ex, int id) async {
    final rows = await ex.query(
      'incidents',
      columns: ['statut'],
      where: 'id = ?',
      whereArgs: [id],
    );
    return rows.isEmpty
        ? null
        : IncidentStatus.fromValue(rows.first['statut'] as String);
  }

  Future<void> _logStatus(
    DatabaseExecutor ex,
    int incidentId, {
    required IncidentStatus? from,
    required IncidentStatus to,
    int? byUserId,
    DateTime? at,
  }) => ex.insert('incident_history', {
    'incident_id': incidentId,
    'from_statut': from?.value,
    'to_statut': to.value,
    'changed_by_user_id': byUserId,
    'changed_at': (at ?? DateTime.now()).toIso8601String(),
  });

  Future<void> delete(int id) async {
    final db = await _db;
    final photos = await getPhotos(id);
    try {
      await db.delete('incidents', where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintError()) {
        throw const AppException(
          'Suppression impossible : élément utilisé ailleurs.',
        );
      }
      rethrow;
    }
    for (final f in photos) {
      await ImageStorage.delete(f);
    }
  }

  Future<List<Incident>> getByVehicle(int vehicleId) async {
    final db = await _db;
    final rows = await db.query(
      'incidents',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
      orderBy: 'date DESC',
    );
    return [
      for (final r in rows)
        Incident.fromMap(r, photos: await getPhotos(r['id'] as int)),
    ];
  }

  Future<void> _writePhotos(
    DatabaseExecutor ex,
    int incidentId,
    List<String> files,
  ) async {
    await ex.delete(
      'incident_photos',
      where: 'incident_id = ?',
      whereArgs: [incidentId],
    );
    for (var i = 0; i < files.length; i++) {
      await ex.insert('incident_photos', {
        'incident_id': incidentId,
        'file_name': files[i],
        'position': i,
      });
    }
  }
}
