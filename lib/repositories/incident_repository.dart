import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/services/image_storage.dart';
import '../core/utils/app_exception.dart';
import '../models/enums.dart';
import '../models/incident.dart';

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
      final like = '%${q.replaceAllMapped(RegExp(r'[\\%_]'), (m) => '\\${m[0]}')}%';
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
        'SELECT statut, COUNT(*) AS n FROM incidents GROUP BY statut');
    final counts = {for (final s in IncidentStatus.values) s: 0};
    for (final r in rows) {
      counts[IncidentStatus.fromValue(r['statut'] as String)] = r['n'] as int;
    }
    return counts;
  }

  Future<IncidentView?> getViewById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('$_viewSelect WHERE i.id = ?', [id]);
    if (rows.isEmpty) return null;
    return _toView(rows.first);
  }

  Future<Incident?> getById(int id) async {
    final db = await _db;
    final rows =
        await db.query('incidents', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Incident.fromMap(rows.first, photos: await getPhotos(id));
  }

  Future<List<String>> getPhotos(int incidentId) async {
    final db = await _db;
    final rows = await db.query('incident_photos',
        where: 'incident_id = ?',
        whereArgs: [incidentId],
        orderBy: 'position');
    return [for (final r in rows) r['file_name'] as String];
  }

  Future<int> insert(Incident inc) async {
    final db = await _db;
    return db.transaction((txn) async {
      final id = await txn.insert('incidents', inc.toMap());
      await _writePhotos(txn, id, inc.photos);
      return id;
    });
  }

  Future<void> update(Incident inc) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.update('incidents', inc.toMap(),
          where: 'id = ?', whereArgs: [inc.id]);
      await _writePhotos(txn, inc.id!, inc.photos);
    });
  }

  Future<void> changeStatus(int id, IncidentStatus status) async {
    final db = await _db;
    await db.update('incidents', {'statut': status.value},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    final photos = await getPhotos(id);
    try {
      await db.delete('incidents', where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintError()) {
        throw const AppException('Suppression impossible : élément utilisé ailleurs.');
      }
      rethrow;
    }
    for (final f in photos) {
      await ImageStorage.delete(f);
    }
  }

  Future<List<Incident>> getByVehicle(int vehicleId) async {
    final db = await _db;
    final rows = await db.query('incidents',
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
        orderBy: 'date DESC');
    return [
      for (final r in rows)
        Incident.fromMap(r, photos: await getPhotos(r['id'] as int))
    ];
  }

  Future<void> _writePhotos(
      DatabaseExecutor ex, int incidentId, List<String> files) async {
    await ex.delete('incident_photos',
        where: 'incident_id = ?', whereArgs: [incidentId]);
    for (var i = 0; i < files.length; i++) {
      await ex.insert('incident_photos', {
        'incident_id': incidentId,
        'file_name': files[i],
        'position': i,
      });
    }
  }
}
