import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../models/enums.dart';
import '../models/maintenance.dart';

class MaintenanceRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<Maintenance>> getByVehicle(int vehicleId) async {
    final db = await _db;
    final rows = await db.query('maintenances',
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
        orderBy: 'date DESC');
    return [for (final r in rows) Maintenance.fromMap(r)];
  }

  Future<List<MaintenanceView>> getViewsByStatus(
      MaintenanceStatus status) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT m.*, v.marque || ' ' || v.modele || ' · ' || v.immatriculation AS vehicle_label
      FROM maintenances m
      JOIN vehicles v ON v.id = m.vehicle_id
      WHERE m.statut = ?
      ORDER BY m.date DESC
    ''', [status.value]);
    return [
      for (final r in rows)
        MaintenanceView(
          maintenance: Maintenance.fromMap(r),
          vehicleLabel: r['vehicle_label'] as String,
        )
    ];
  }

  Future<Maintenance?> getById(int id) async {
    final db = await _db;
    final rows =
        await db.query('maintenances', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Maintenance.fromMap(rows.first);
  }

  Future<int> insert(Maintenance m) async {
    final db = await _db;
    return db.insert('maintenances', m.toMap());
  }

  Future<void> update(Maintenance m) async {
    final db = await _db;
    await db.update('maintenances', m.toMap(),
        where: 'id = ?', whereArgs: [m.id]);
  }

  Future<void> changeStatus(int id, MaintenanceStatus status) async {
    final db = await _db;
    await db.update('maintenances', {'statut': status.value},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('maintenances', where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> hasActiveMaintenance(int vehicleId) async {
    final db = await _db;
    final r = await db.rawQuery(
        "SELECT COUNT(*) FROM maintenances WHERE vehicle_id = ? AND statut = 'en_cours'",
        [vehicleId]);
    return (Sqflite.firstIntValue(r) ?? 0) > 0;
  }
}
