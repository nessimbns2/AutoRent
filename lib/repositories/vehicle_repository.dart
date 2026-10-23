import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/services/image_storage.dart';
import '../core/utils/app_exception.dart';
import '../models/enums.dart';
import '../models/vehicle.dart';

class VehicleRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Vehicle>> getAll({bool? availableOnly, String? search}) async {
    final db = await _db;
    final where = <String>[];
    final args = <Object?>[];
    if (availableOnly == true) where.add('disponible = 1');
    if (availableOnly == false) where.add('disponible = 0');
    if (search != null && search.trim().isNotEmpty) {
      where.add(
          '(LOWER(marque) LIKE ? OR LOWER(modele) LIKE ? OR LOWER(immatriculation) LIKE ?)');
      final like = '%${search.trim().toLowerCase()}%';
      args.addAll([like, like, like]);
    }
    final rows = await db.query(
      'vehicles',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'marque, modele',
    );
    return [
      for (final r in rows)
        Vehicle.fromMap(r, photos: await getPhotos(r['id'] as int))
    ];
  }

  Future<Vehicle?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('vehicles', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Vehicle.fromMap(rows.first, photos: await getPhotos(id));
  }

  Future<List<String>> getPhotos(int vehicleId) async {
    final db = await _db;
    final rows = await db.query('vehicle_photos',
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
        orderBy: 'position');
    return [for (final r in rows) r['file_name'] as String];
  }

  Future<int> insert(Vehicle v) async {
    final db = await _db;
    if (await immatExists(v.plate)) {
      throw const AppException('Cette immatriculation existe déjà.');
    }
    return db.transaction((txn) async {
      final id = await txn.insert('vehicles', v.toMap());
      await _writePhotos(txn, id, v.photos);
      return id;
    });
  }

  Future<void> update(Vehicle v) async {
    final db = await _db;
    if (await immatExists(v.plate, excludeId: v.id)) {
      throw const AppException('Cette immatriculation existe déjà.');
    }
    await db.transaction((txn) async {
      await txn.update('vehicles', v.toMap(),
          where: 'id = ?', whereArgs: [v.id]);
      await _writePhotos(txn, v.id!, v.photos);
    });
  }

  Future<void> delete(int id) async {
    final db = await _db;
    final photos = await getPhotos(id);
    try {
      await db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintError()) {
        throw const AppException(
            'Suppression impossible : ce véhicule a des locations ou des incidents.');
      }
      rethrow;
    }
    for (final f in photos) {
      await ImageStorage.delete(f);
    }
  }

  Future<bool> immatExists(String plate, {int? excludeId}) async {
    final db = await _db;
    final where = excludeId == null
        ? 'LOWER(immatriculation) = ?'
        : 'LOWER(immatriculation) = ? AND id != ?';
    final args = excludeId == null
        ? [plate.trim().toLowerCase()]
        : [plate.trim().toLowerCase(), excludeId];
    final rows =
        await db.query('vehicles', where: where, whereArgs: args, limit: 1);
    return rows.isNotEmpty;
  }

  Future<List<Vehicle>> getAvailableForRange(
    DateTime start,
    DateTime end, {
    int? excludeRentalId,
  }) async {
    final db = await _db;
    // Available = disponible=1, no active maintenance en_cours, no overlapping rental
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);

    final rows = await db.rawQuery('''
      SELECT v.* FROM vehicles v
      WHERE v.disponible = 1
        AND v.id NOT IN (
          SELECT vehicle_id FROM maintenances WHERE statut = 'en_cours'
        )
        AND v.id NOT IN (
          SELECT vehicle_id FROM rentals
          WHERE statut IN ('reservee','en_cours')
            AND date_debut <= ? AND date_fin >= ?
            ${excludeRentalId != null ? 'AND id != ?' : ''}
        )
      ORDER BY v.marque, v.modele
    ''', [
      endStr,
      startStr,
      ?excludeRentalId,
    ]);

    return [
      for (final r in rows)
        Vehicle.fromMap(r, photos: await getPhotos(r['id'] as int))
    ];
  }

  Future<VehicleAvailability> getAvailabilityState(int vehicleId) async {
    final db = await _db;
    final vehicle = await getById(vehicleId);
    if (vehicle == null) return VehicleAvailability.indisponible;

    // Check en_cours maintenance
    final maintenanceRows = await db.query('maintenances',
        where: "vehicle_id = ? AND statut = 'en_cours'",
        whereArgs: [vehicleId],
        limit: 1);
    if (maintenanceRows.isNotEmpty) return VehicleAvailability.enEntretien;

    // Check active rental
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final rentalRows = await db.rawQuery('''
      SELECT id FROM rentals
      WHERE vehicle_id = ? AND statut = 'en_cours'
        AND date_debut <= ? AND date_fin >= ?
      LIMIT 1
    ''', [vehicleId, today, today]);
    if (rentalRows.isNotEmpty) return VehicleAvailability.louee;

    if (!vehicle.available) return VehicleAvailability.indisponible;
    return VehicleAvailability.disponible;
  }

  Future<void> _writePhotos(
      DatabaseExecutor ex, int vehicleId, List<String> files) async {
    await ex.delete('vehicle_photos',
        where: 'vehicle_id = ?', whereArgs: [vehicleId]);
    for (var i = 0; i < files.length; i++) {
      await ex.insert('vehicle_photos', {
        'vehicle_id': vehicleId,
        'file_name': files[i],
        'position': i,
      });
    }
  }
}
