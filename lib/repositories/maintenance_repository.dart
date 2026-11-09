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
    final values = <String, Object?>{'statut': status.value};
    // Record when the maintenance actually starts.
    if (status == MaintenanceStatus.enCours) {
      values['started_at'] = DateTime.now().toIso8601String();
    }
    await db.update('maintenances', values,
        where: 'id = ?', whereArgs: [id]);
  }

  /// Mark a maintenance as completed with optional final cost and mileage.
  Future<void> complete(int id, {double? costActual, int? mileage}) async {
    final db = await _db;
    final values = <String, Object?>{
      'statut': MaintenanceStatus.termine.value,
      'ended_at': DateTime.now().toIso8601String(),
    };
    if (costActual != null) values['cout_reel'] = costActual;
    if (mileage != null) values['kilometrage'] = mileage;
    await db.update('maintenances', values, where: 'id = ?', whereArgs: [id]);
  }

  /// Days the vehicle was in the workshop. Minimum 1 even if same day.
  int immoDays(DateTime startedAt, DateTime endedAt) {
    final days = endedAt.difference(startedAt).inDays;
    return days < 1 ? 1 : days;
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('maintenances', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<MaintenanceStatus, int>> countByStatus() async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT statut, COUNT(*) AS cnt FROM maintenances GROUP BY statut');
    return {
      for (final r in rows)
        MaintenanceStatus.fromValue(r['statut'] as String): r['cnt'] as int
    };
  }

  Future<bool> hasActiveMaintenance(int vehicleId) async {
    final db = await _db;
    final r = await db.rawQuery(
        "SELECT COUNT(*) FROM maintenances WHERE vehicle_id = ? AND statut = 'en_cours'",
        [vehicleId]);
    return (Sqflite.firstIntValue(r) ?? 0) > 0;
  }

  /// Returns all statistics for the stats screen, filtered by [since] date.
  /// All heavy work is done here — the UI only displays the result.
  Future<MaintenanceStats> getStats({DateTime? since}) async {
    final db = await _db;
    final where = since != null
        ? "AND m.date >= '${since.toIso8601String().substring(0, 10)}'"
        : '';

    // All maintenances in the period with vehicle label & daily rate.
    final rows = await db.rawQuery('''
      SELECT m.*,
             v.marque || ' ' || v.modele || ' · ' || v.immatriculation AS vehicle_label,
             v.prix_par_jour AS daily_rate
      FROM maintenances m
      JOIN vehicles v ON v.id = m.vehicle_id
      WHERE 1=1 $where
      ORDER BY m.date DESC
    ''');
    final all = [for (final r in rows) StatsRow.fromMap(r)];

    // KPIs
    double totalCost = 0;
    int totalDays = 0;
    double totalLostRevenue = 0;
    final countByType = <String, int>{};
    final costByType = <String, double>{};
    final costByVehicle = <int, VehicleAgg>{};

    for (final r in all) {
      final cost = r.costActual ?? r.costEstimated ?? 0.0;
      if (r.costActual != null) totalCost += r.costActual!;

      countByType[r.type] = (countByType[r.type] ?? 0) + 1;
      costByType[r.type] = (costByType[r.type] ?? 0.0) + cost;

      int days = 0;
      if (r.startedAt != null && r.endedAt != null) {
        days = immoDays(r.startedAt!, r.endedAt!);
        totalDays += days;
        totalLostRevenue += days * r.dailyRate;
      }

      final agg = costByVehicle[r.vehicleId] ??
          VehicleAgg(r.vehicleId, r.vehicleLabel, r.dailyRate);
      agg.totalCost += cost;
      agg.totalDays += days;
      costByVehicle[r.vehicleId] = agg;
    }

    // Monthly costs — last 6 months, keyed as 'yyyy-MM'
    final now = DateTime.now();
    final monthlyCosts = <String, double>{};
    for (int i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final key = '${m.year}-${m.month.toString().padLeft(2, '0')}';
      monthlyCosts[key] = 0.0;
    }
    for (final r in all) {
      final key = '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}';
      if (monthlyCosts.containsKey(key)) {
        monthlyCosts[key] =
            (monthlyCosts[key] ?? 0) + (r.costActual ?? r.costEstimated ?? 0.0);
      }
    }

    final top3 = costByVehicle.values.toList()
      ..sort((a, b) => b.totalCost.compareTo(a.totalCost));

    return MaintenanceStats(
      all: all,
      totalCost: totalCost,
      totalInterventions: all.length,
      totalDays: totalDays,
      totalLostRevenue: totalLostRevenue,
      countByType: countByType,
      costByType: costByType,
      monthlyCosts: monthlyCosts,
      top3Vehicles: top3.take(3).toList(),
    );
  }
}

// ── Data classes (public so the stats screen can reference them) ──────────────

class StatsRow {
  final int id;
  final int vehicleId;
  final String vehicleLabel;
  final double dailyRate;
  final String type;
  final DateTime date;
  final double? costEstimated;
  final double? costActual;
  final DateTime? startedAt;
  final DateTime? endedAt;

  const StatsRow({
    required this.id,
    required this.vehicleId,
    required this.vehicleLabel,
    required this.dailyRate,
    required this.type,
    required this.date,
    this.costEstimated,
    this.costActual,
    this.startedAt,
    this.endedAt,
  });

  factory StatsRow.fromMap(Map<String, Object?> m) => StatsRow(
        id: m['id'] as int,
        vehicleId: m['vehicle_id'] as int,
        vehicleLabel: m['vehicle_label'] as String,
        dailyRate: (m['daily_rate'] as num).toDouble(),
        type: m['type'] as String,
        date: DateTime.parse(m['date'] as String),
        costEstimated: (m['cout_estime'] as num?)?.toDouble(),
        costActual: (m['cout_reel'] as num?)?.toDouble(),
        startedAt: m['started_at'] != null
            ? DateTime.parse(m['started_at'] as String)
            : null,
        endedAt: m['ended_at'] != null
            ? DateTime.parse(m['ended_at'] as String)
            : null,
      );
}

class VehicleAgg {
  final int vehicleId;
  final String vehicleLabel;
  final double dailyRate;
  double totalCost = 0;
  int totalDays = 0;

  VehicleAgg(this.vehicleId, this.vehicleLabel, this.dailyRate);

  double get totalImpact => totalCost + totalDays * dailyRate;
}

class MaintenanceStats {
  final List<StatsRow> all;
  final double totalCost;
  final int totalInterventions;
  final int totalDays;
  final double totalLostRevenue;
  final Map<String, int> countByType;
  final Map<String, double> costByType;
  final Map<String, double> monthlyCosts; // key: 'yyyy-MM'
  final List<VehicleAgg> top3Vehicles;

  const MaintenanceStats({
    required this.all,
    required this.totalCost,
    required this.totalInterventions,
    required this.totalDays,
    required this.totalLostRevenue,
    required this.countByType,
    required this.costByType,
    required this.monthlyCosts,
    required this.top3Vehicles,
  });

  bool get isEmpty => all.isEmpty;
}
