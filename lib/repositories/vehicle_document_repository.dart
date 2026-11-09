import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/utils/formatters.dart';
import '../models/vehicle_document.dart';

/// A document with the vehicle it belongs to (for alerts and exports).
class DocumentAlertRow {
  final VehicleDocument document;
  final String vehicleName;
  final String plate;
  const DocumentAlertRow(this.document, this.vehicleName, this.plate);
}

/// Administrative documents of the vehicles (insurance, roadworthiness test,
/// road tax, registration) — one current document per type and vehicle.
class VehicleDocumentRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  static final _blockingTypes = [
    for (final t in DocumentType.values)
      if (t.blocksRental) "'${t.value}'"
  ].join(',');

  Future<Map<DocumentType, VehicleDocument>> getByVehicle(int vehicleId) async {
    final db = await _db;
    final rows = await db.query('vehicle_documents',
        where: 'vehicle_id = ?', whereArgs: [vehicleId]);
    return {
      for (final r in rows)
        DocumentType.fromValue(r['type'] as String): VehicleDocument.fromMap(r)
    };
  }

  /// Creates or replaces the document of [doc.type] for the vehicle.
  Future<void> save(VehicleDocument doc) async {
    final db = await _db;
    await db.insert('vehicle_documents', doc.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> remove(int vehicleId, DocumentType type) async {
    final db = await _db;
    await db.delete('vehicle_documents',
        where: 'vehicle_id = ? AND type = ?',
        whereArgs: [vehicleId, type.value]);
  }

  /// Saves the documents typed in the vehicle form: a date creates/updates
  /// the document, no date removes it.
  Future<void> saveAll(
    int vehicleId,
    Map<DocumentType, ({DateTime? expiresOn, String? number})> docs,
  ) async {
    final now = DateTime.now();
    for (final e in docs.entries) {
      final date = e.value.expiresOn;
      if (date == null) {
        await remove(vehicleId, e.key);
      } else {
        final number = e.value.number?.trim();
        await save(VehicleDocument(
          vehicleId: vehicleId,
          type: e.key,
          number: (number == null || number.isEmpty) ? null : number,
          expiresOn: date,
          updatedAt: now,
        ));
      }
    }
  }

  /// Why the vehicle cannot be rented until [until] (insurance or
  /// roadworthiness test expired before that date), or null when it can.
  Future<String?> blockingIssue(int vehicleId, DateTime until) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT * FROM vehicle_documents
      WHERE vehicle_id = ? AND type IN ($_blockingTypes) AND date_expiration < ?
      ORDER BY date_expiration ASC LIMIT 1
    ''', [vehicleId, toIsoDate(until)]);
    if (rows.isEmpty) return null;
    final d = VehicleDocument.fromMap(rows.first);
    final today = DateTime.now();
    final expired = DateTime(d.expiresOn.year, d.expiresOn.month,
            d.expiresOn.day)
        .isBefore(DateTime(today.year, today.month, today.day));
    final what = d.type == DocumentType.assurance
        ? "l'assurance"
        : 'la visite technique';
    return expired
        ? 'Location impossible : $what est expirée depuis le ${formatDate(d.expiresOn)}.'
        : 'Location impossible : $what expire le ${formatDate(d.expiresOn)}, '
            'avant la fin de la location.';
  }

  /// Documents of active (non-archived) vehicles expiring before
  /// today + [withinDays] (expired ones included).
  Future<List<DocumentAlertRow>> expiringWithin(int withinDays) async {
    final db = await _db;
    final limit = toIsoDate(DateTime.now().add(Duration(days: withinDays)));
    final rows = await db.rawQuery('''
      SELECT d.*, v.marque || ' ' || v.modele AS vehicle_name, v.immatriculation
      FROM vehicle_documents d JOIN vehicles v ON v.id = d.vehicle_id
      WHERE v.archive = 0 AND d.date_expiration <= ?
      ORDER BY d.date_expiration ASC
    ''', [limit]);
    return [
      for (final r in rows)
        DocumentAlertRow(VehicleDocument.fromMap(r),
            r['vehicle_name'] as String, r['immatriculation'] as String)
    ];
  }

  /// Every document of every vehicle, keyed by vehicle id (CSV export).
  Future<Map<int, Map<DocumentType, VehicleDocument>>> all() async {
    final db = await _db;
    final out = <int, Map<DocumentType, VehicleDocument>>{};
    for (final r in await db.query('vehicle_documents')) {
      final d = VehicleDocument.fromMap(r);
      out.putIfAbsent(d.vehicleId, () => {})[d.type] = d;
    }
    return out;
  }
}
