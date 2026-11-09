import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/utils/formatters.dart';
import '../models/enums.dart';
import '../models/maintenance.dart';
import '../models/rental.dart';
import 'rental_repository.dart';

class FleetStatus {
  final int total;
  final int available;
  final int rented;
  final int maintenance;
  final int unavailable;
  const FleetStatus({
    required this.total,
    required this.available,
    required this.rented,
    required this.maintenance,
    required this.unavailable,
  });

  double get occupancy => total == 0 ? 0 : rented / total;
}

class MonthRevenue {
  final int year;
  final int month;
  final double amount;
  const MonthRevenue(this.year, this.month, this.amount);
}

class DashboardData {
  final FleetStatus fleet;
  final Map<RentalStatus, int> rentalsByStatus;
  final int overdue;
  final int pendingIncidents;
  final int openMaintenances;
  final List<MonthRevenue> revenue; // oldest → newest, 6 months
  final List<RentalView> departures;
  final List<RentalView> returns;
  final List<MaintenanceView> upcomingMaintenances;

  const DashboardData({
    required this.fleet,
    required this.rentalsByStatus,
    required this.overdue,
    required this.pendingIncidents,
    required this.openMaintenances,
    required this.revenue,
    required this.departures,
    required this.returns,
    required this.upcomingMaintenances,
  });

  double get monthRevenue => revenue.isEmpty ? 0 : revenue.last.amount;
  double get previousMonthRevenue =>
      revenue.length < 2 ? 0 : revenue[revenue.length - 2].amount;

  /// Month-over-month evolution in percent (null when no reference).
  double? get revenueTrend => previousMonthRevenue == 0
      ? null
      : (monthRevenue - previousMonthRevenue) / previousMonthRevenue * 100;
}

/// Aggregated figures for the home dashboard (read-only queries).
class DashboardRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;
  final _rentals = RentalRepository();

  Future<DashboardData> load() async {
    final db = await _db;
    final now = DateTime.now();
    final today = toIsoDate(now);

    // ── Fleet status (same rules as VehicleRepository.getAvailabilityState)
    final fleetRows = await db.rawQuery('''
      SELECT v.id, v.disponible,
        EXISTS(SELECT 1 FROM maintenances m
               WHERE m.vehicle_id = v.id AND m.statut = 'en_cours') AS in_maint,
        EXISTS(SELECT 1 FROM rentals r
               WHERE r.vehicle_id = v.id AND r.statut = 'en_cours'
                 AND r.date_debut <= ? AND r.date_fin >= ?) AS rented,
        EXISTS(SELECT 1 FROM vehicle_documents d
               WHERE d.vehicle_id = v.id
                 AND d.type IN ('assurance','visite_technique')
                 AND d.date_expiration < ?) AS docs_expired
      FROM vehicles v
      WHERE v.archive = 0
    ''', [today, today, today]);
    var available = 0, rented = 0, maint = 0, unavailable = 0;
    for (final r in fleetRows) {
      if ((r['in_maint'] as int) == 1) {
        maint++;
      } else if ((r['rented'] as int) == 1) {
        rented++;
      } else if ((r['disponible'] as int) == 0 ||
          (r['docs_expired'] as int) == 1) {
        unavailable++;
      } else {
        available++;
      }
    }

    // ── Rentals by status
    final statusRows = await db.rawQuery(
        'SELECT statut, COUNT(*) AS cnt FROM rentals GROUP BY statut');
    final byStatus = <RentalStatus, int>{};
    for (final r in statusRows) {
      try {
        byStatus[RentalStatus.fromValue(r['statut'] as String)] =
            r['cnt'] as int;
      } catch (_) {}
    }

    final overdue = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM rentals WHERE statut = 'en_cours' AND date_fin < ?",
            [today])) ??
        0;

    final pendingIncidents = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM incidents WHERE statut != 'resolu'")) ??
        0;

    final openMaintenances = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM maintenances WHERE statut != 'termine'")) ??
        0;

    // ── Revenue for the last 6 months (by rental start date, not cancelled)
    final start = DateTime(now.year, now.month - 5, 1);
    final revRows = await db.rawQuery('''
      SELECT substr(date_debut, 1, 7) AS ym, SUM(prix_total) AS total
      FROM rentals
      WHERE statut != 'annulee' AND date_debut >= ?
      GROUP BY ym
    ''', [toIsoDate(start)]);
    final revMap = {
      for (final r in revRows)
        r['ym'] as String: (r['total'] as num?)?.toDouble() ?? 0.0
    };
    final revenue = <MonthRevenue>[
      for (var i = 0; i < 6; i++)
        () {
          final d = DateTime(start.year, start.month + i, 1);
          final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';
          return MonthRevenue(d.year, d.month, revMap[key] ?? 0);
        }(),
    ];

    // ── Today's agenda
    final departures = await _rentals.queryViews(
      "r.statut = 'reservee' AND r.date_debut <= ?",
      [today],
      orderBy: 'r.date_debut ASC',
      limit: 5,
    );
    final returns = await _rentals.queryViews(
      "r.statut = 'en_cours' AND r.date_fin <= ?",
      [today],
      orderBy: 'r.date_fin ASC',
      limit: 5,
    );

    // ── Maintenance in the next 14 days (or already running)
    final horizon = toIsoDate(now.add(const Duration(days: 14)));
    final mRows = await db.rawQuery('''
      SELECT m.*, v.marque || ' ' || v.modele || ' · ' || v.immatriculation AS vehicle_label
      FROM maintenances m JOIN vehicles v ON v.id = m.vehicle_id
      WHERE m.statut = 'en_cours' OR (m.statut = 'planifie' AND m.date <= ?)
      ORDER BY CASE m.statut WHEN 'en_cours' THEN 0 ELSE 1 END, m.date ASC
      LIMIT 4
    ''', [horizon]);
    final upcoming = [
      for (final r in mRows)
        MaintenanceView(
          maintenance: Maintenance.fromMap(r),
          vehicleLabel: r['vehicle_label'] as String,
        )
    ];

    return DashboardData(
      fleet: FleetStatus(
        total: fleetRows.length,
        available: available,
        rented: rented,
        maintenance: maint,
        unavailable: unavailable,
      ),
      rentalsByStatus: byStatus,
      overdue: overdue,
      pendingIncidents: pendingIncidents,
      openMaintenances: openMaintenances,
      revenue: revenue,
      departures: departures,
      returns: returns,
      upcomingMaintenances: upcoming,
    );
  }
}
