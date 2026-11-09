import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/utils/app_exception.dart';
import '../models/enums.dart';
import '../models/rental.dart';

class RentalRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<List<RentalView>> getViewsByStatus(
    RentalStatus status, {
    int? userId,
    String? userEmail,
    String? search,
  }) {
    final where = <String>['r.statut = ?'];
    final args = <Object?>[status.value];

    if (userId != null || (userEmail != null && userEmail.isNotEmpty)) {
      final userConditions = <String>[];
      if (userId != null) {
        userConditions.add('r.user_id = ?');
        args.add(userId);
      }
      if (userEmail != null && userEmail.isNotEmpty) {
        userConditions.add('LOWER(c.email) = ?');
        args.add(userEmail.toLowerCase());
      }
      where.add('(${userConditions.join(' OR ')})');
    }

    if (search != null && search.trim().isNotEmpty) {
      final like = '%${search.trim().toLowerCase()}%';
      where.add('(LOWER(c.nom) LIKE ? OR LOWER(c.prenom) LIKE ? '
          'OR LOWER(v.marque) LIKE ? OR LOWER(v.modele) LIKE ? '
          'OR LOWER(v.immatriculation) LIKE ?)');
      args.addAll([like, like, like, like, like]);
    }

    return queryViews(where.join(' AND '), args);
  }

  static const _viewSelect = '''
    SELECT r.*,
           c.prenom || ' ' || c.nom AS client_name,
           v.marque || ' ' || v.modele || ' · ' || v.immatriculation AS vehicle_label,
           u.prenom || ' ' || u.nom AS user_name
    FROM rentals r
    JOIN clients c ON c.id = r.client_id
    JOIN vehicles v ON v.id = r.vehicle_id
    LEFT JOIN users u ON u.id = r.user_id
  ''';

  /// Generic joined query used by the dashboard and detail screens.
  Future<List<RentalView>> queryViews(
    String where,
    List<Object?> args, {
    String orderBy = 'r.date_debut DESC',
    int? limit,
  }) async {
    final db = await _db;
    final rows = await db.rawQuery(
      '$_viewSelect WHERE $where ORDER BY $orderBy'
      '${limit != null ? ' LIMIT $limit' : ''}',
      args,
    );
    return [
      for (final r in rows)
        RentalView(
          rental: Rental.fromMap(r),
          clientName: r['client_name'] as String,
          vehicleLabel: r['vehicle_label'] as String,
          userName: r['user_name'] as String?,
        )
    ];
  }

  Future<List<RentalView>> getViewsByVehicle(int vehicleId) =>
      queryViews('r.vehicle_id = ?', [vehicleId]);

  Future<RentalView?> getViewById(int id) async {
    final list = await queryViews('r.id = ?', [id]);
    return list.isEmpty ? null : list.first;
  }

  Future<Rental?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('rentals', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Rental.fromMap(rows.first);
  }

  Future<int> insert(Rental r) async {
    final db = await _db;
    return db.insert('rentals', r.toMap());
  }

  Future<void> update(Rental r) async {
    final db = await _db;
    await db.update('rentals', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
  }

  /// Pushes the end date back, keeping the daily rate. Throws if the car is
  /// already booked on the added days.
  Future<void> extend(Rental r, DateTime newEnd) async {
    final from = r.endDate.add(const Duration(days: 1));
    if (newEnd.isBefore(from)) {
      throw const AppException(
          'La nouvelle date doit être après le retour prévu.');
    }
    if (await hasOverlap(r.vehicleId, from, newEnd, excludeId: r.id)) {
      throw const AppException(
          'Le véhicule est déjà réservé sur cette période.');
    }
    final extended = r.copyWith(endDate: newEnd);
    await update(extended.copyWith(
        totalPrice: r.totalPrice / r.days * extended.days));
  }

  Future<void> changeStatus(int id, RentalStatus status) async {
    final db = await _db;
    await db.update('rentals', {'statut': status.value},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    try {
      await db.delete('rentals', where: 'id = ?', whereArgs: [id]);
    } on DatabaseException catch (e) {
      if (e.isForeignKeyConstraintError()) {
        throw const AppException('Suppression impossible : élément utilisé ailleurs.');
      }
      rethrow;
    }
  }

  /// Returns true if there is an overlapping active rental for [vehicleId].
  Future<bool> hasOverlap(
    int vehicleId,
    DateTime start,
    DateTime end, {
    int? excludeId,
  }) async {
    final db = await _db;
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);
    final args = <Object?>[vehicleId, endStr, startStr];
    String extra = '';
    if (excludeId != null) {
      extra = 'AND id != ?';
      args.add(excludeId);
    }
    final r = await db.rawQuery('''
      SELECT COUNT(*) FROM rentals
      WHERE vehicle_id = ? AND statut IN ('reservee','en_cours')
        AND date_debut <= ? AND date_fin >= ?
        $extra
    ''', args);
    return (Sqflite.firstIntValue(r) ?? 0) > 0;
  }

  /// Returns the active rental (en_cours) for a vehicle on a given date, or null.
  Future<Rental?> getActiveForVehicle(int vehicleId, DateTime date) async {
    final db = await _db;
    final dateStr = date.toIso8601String().substring(0, 10);
    final rows = await db.rawQuery('''
      SELECT * FROM rentals
      WHERE vehicle_id = ? AND statut = 'en_cours'
        AND date_debut <= ? AND date_fin >= ?
      LIMIT 1
    ''', [vehicleId, dateStr, dateStr]);
    return rows.isEmpty ? null : Rental.fromMap(rows.first);
  }

  Future<Map<RentalStatus, int>> countByStatus({
    int? userId,
    String? userEmail,
  }) async {
    final db = await _db;
    String sql;
    List<Object?> args = [];
    if (userId != null || (userEmail != null && userEmail.isNotEmpty)) {
      final userConditions = <String>[];
      if (userId != null) {
        userConditions.add('r.user_id = ?');
        args.add(userId);
      }
      if (userEmail != null && userEmail.isNotEmpty) {
        userConditions.add('LOWER(c.email) = ?');
        args.add(userEmail.toLowerCase());
      }
      sql = '''
        SELECT r.statut, COUNT(*) AS cnt
        FROM rentals r
        JOIN clients c ON c.id = r.client_id
        WHERE ${userConditions.join(' OR ')}
        GROUP BY r.statut
      ''';
    } else {
      sql = 'SELECT statut, COUNT(*) AS cnt FROM rentals GROUP BY statut';
    }
    final rows = await db.rawQuery(sql, args);
    final result = <RentalStatus, int>{};
    for (final r in rows) {
      try {
        final status = RentalStatus.fromValue(r['statut'] as String);
        result[status] = r['cnt'] as int;
      } catch (_) {}
    }
    return result;
  }

  Future<List<Rental>> getByClient(int clientId) async {
    final db = await _db;
    final rows = await db.query('rentals',
        where: 'client_id = ?', whereArgs: [clientId], orderBy: 'date_debut DESC');
    return [for (final r in rows) Rental.fromMap(r)];
  }
}
