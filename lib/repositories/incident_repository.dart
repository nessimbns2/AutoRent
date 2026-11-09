import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/services/image_storage.dart';
import '../core/utils/app_exception.dart';
import '../models/enums.dart';
import '../models/incident.dart';

class IncidentRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<IncidentView>> getViewsByStatus(IncidentStatus status) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT i.*,
             v.marque || ' ' || v.modele || ' · ' || v.immatriculation AS vehicle_label,
             u.nom || ' ' || u.prenom AS reporter_name
      FROM incidents i
      JOIN vehicles v ON v.id = i.vehicle_id
      LEFT JOIN users u ON u.id = i.reported_by_user_id
      WHERE i.statut = ?
      ORDER BY i.date DESC
    ''', [status.value]);
    return [
      for (final r in rows)
        IncidentView(
          incident:
              Incident.fromMap(r, photos: await getPhotos(r['id'] as int)),
          vehicleLabel: r['vehicle_label'] as String,
          reporterName: r['reporter_name'] as String?,
        )
    ];
  }

  Future<IncidentView?> getViewById(int id) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT i.*,
             v.marque || ' ' || v.modele || ' · ' || v.immatriculation AS vehicle_label,
             u.nom || ' ' || u.prenom AS reporter_name
      FROM incidents i
      JOIN vehicles v ON v.id = i.vehicle_id
      LEFT JOIN users u ON u.id = i.reported_by_user_id
      WHERE i.id = ?
    ''', [id]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return IncidentView(
      incident: Incident.fromMap(r, photos: await getPhotos(id)),
      vehicleLabel: r['vehicle_label'] as String,
      reporterName: r['reporter_name'] as String?,
    );
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
