import 'package:flutter/material.dart' show DateUtils;
import 'package:sqflite/sqflite.dart';

import '../core/constants/business_rules.dart';
import '../core/database/database_helper.dart';
import '../core/utils/app_exception.dart';
import '../core/utils/formatters.dart';
import '../models/enums.dart';
import '../models/rental.dart';
import '../models/rental_stats.dart';
import 'dashboard_repository.dart' show MonthRevenue;

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

  /// Every day (`yyyy-MM-dd`) a vehicle is reserved or rented.
  Future<Set<String>> bookedDays(int vehicleId, {int? excludeId}) async {
    final days = <String>{};
    for (final v in await getViewsByVehicle(vehicleId)) {
      final r = v.rental;
      if (r.id == excludeId ||
          (r.status != RentalStatus.reservee &&
              r.status != RentalStatus.enCours)) {
        continue;
      }
      for (var d = r.startDate;
          !d.isAfter(r.endDate);
          d = d.add(const Duration(days: 1))) {
        days.add(toIsoDate(d));
      }
    }
    return days;
  }

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

  /// Extends a running or reserved contract up to [newEnd] at the same
  /// daily rate. Refused if another booking overlaps the new period.
  Future<Rental> extend(Rental r, DateTime newEnd) async {
    if (!DateUtils.dateOnly(newEnd).isAfter(DateUtils.dateOnly(r.endDate))) {
      throw const AppException(
          'La nouvelle date de retour doit être après la date actuelle.');
    }
    if (await hasOverlap(r.vehicleId, r.startDate, newEnd, excludeId: r.id)) {
      throw const AppException(
          'Prolongation impossible : le véhicule est déjà réservé sur cette période.');
    }
    final updated = r.copyWith(
      endDate: newEnd,
      totalPrice: BusinessRules.extendedTotal(r, newEnd),
    );
    await update(updated);
    return updated;
  }

  /// Closes a running contract. A late return moves the end date to
  /// [returnDate] and adds the late fee to the total.
  Future<void> completeReturn(Rental r, {DateTime? returnDate}) async {
    final today = DateUtils.dateOnly(returnDate ?? DateTime.now());
    final late = BusinessRules.lateDays(r.endDate, today);
    await update(r.copyWith(
      status: RentalStatus.terminee,
      endDate: late > 0 ? today : r.endDate,
      totalPrice: r.totalPrice + BusinessRules.lateFee(r, today),
    ));
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

  /// Figures for the admin analytics page. [now] is injectable for tests.
  Future<RentalStats> getStats({DateTime? now}) async {
    final db = await _db;
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final todayIso = toIsoDate(today);

    final byStatus = <RentalStatus, int>{};
    for (final r in await db
        .rawQuery('SELECT statut, COUNT(*) AS n FROM rentals GROUP BY statut')) {
      byStatus[RentalStatus.fromValue(r['statut'] as String)] = r['n'] as int;
    }

    // One row of totals over every non-cancelled contract.
    final t = (await db.rawQuery('''
      SELECT COALESCE(SUM(prix_total), 0) AS revenue,
             COALESCE(AVG(prix_total), 0) AS avg_amount,
             COALESCE(AVG(MAX(1, julianday(date_fin) - julianday(date_debut))), 0) AS avg_days
      FROM rentals WHERE statut != 'annulee'
    ''')).first;

    final overdue = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM rentals WHERE statut = 'en_cours' AND date_fin < ?",
            [todayIso])) ??
        0;

    // Revenue per month (by start date) for the last 6 months, zero-filled.
    final start = DateTime(today.year, today.month - 5, 1);
    final byMonth = {
      for (final r in await db.rawQuery('''
        SELECT substr(date_debut, 1, 7) AS ym, SUM(prix_total) AS total
        FROM rentals WHERE statut != 'annulee' AND date_debut >= ?
        GROUP BY ym
      ''', [toIsoDate(start)]))
        r['ym'] as String: (r['total'] as num).toDouble()
    };
    final monthly = <MonthRevenue>[
      for (var i = 0; i < 6; i++)
        () {
          final d = DateTime(start.year, start.month + i, 1);
          final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
          return MonthRevenue(d.year, d.month, byMonth[key] ?? 0);
        }(),
    ];

    Future<List<RankedItem>> ranking(String label, String join, String group) async {
      final rows = await db.rawQuery('''
        SELECT $label AS label, COUNT(*) AS n, COALESCE(SUM(r.prix_total), 0) AS revenue
        FROM rentals r $join
        WHERE r.statut != 'annulee'
        GROUP BY $group
        ORDER BY revenue DESC, n DESC
        LIMIT 5
      ''');
      return [
        for (final r in rows)
          RankedItem(r['label'] as String, r['n'] as int,
              (r['revenue'] as num).toDouble())
      ];
    }

    return RentalStats(
      total: byStatus.values.fold(0, (a, b) => a + b),
      byStatus: byStatus,
      revenue: (t['revenue'] as num).toDouble(),
      revenueThisMonth: monthly.last.amount,
      averageAmount: (t['avg_amount'] as num).toDouble(),
      averageDays: (t['avg_days'] as num).toDouble(),
      overdue: overdue,
      monthly: monthly,
      topVehicles: await ranking(
          "v.marque || ' ' || v.modele || ' · ' || v.immatriculation",
          'JOIN vehicles v ON v.id = r.vehicle_id',
          'r.vehicle_id'),
      topClients: await ranking("c.prenom || ' ' || c.nom",
          'JOIN clients c ON c.id = r.client_id', 'r.client_id'),
      byAgent: await ranking(
          "COALESCE(u.prenom || ' ' || u.nom, 'Système')",
          'LEFT JOIN users u ON u.id = r.user_id',
          'r.user_id'),
    );
  }

  Future<List<Rental>> getByClient(int clientId) async {
    final db = await _db;
    final rows = await db.query('rentals',
        where: 'client_id = ?', whereArgs: [clientId], orderBy: 'date_debut DESC');
    return [for (final r in rows) Rental.fromMap(r)];
  }
}
