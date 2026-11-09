import 'package:sqflite/sqflite.dart';

import '../core/database/database_helper.dart';
import '../core/services/pricing_service.dart';
import '../models/pricing_settings.dart';

/// Reads and saves the agency pricing grid (single row of
/// `pricing_settings`) and quotes rentals with it.
class PricingRepository {
  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<PricingSettings> get() async {
    final db = await _db;
    final rows =
        await db.query('pricing_settings', where: 'id = 1', limit: 1);
    return rows.isEmpty
        ? PricingSettings.defaults
        : PricingSettings.fromMap(rows.first);
  }

  Future<void> save(PricingSettings settings) async {
    final db = await _db;
    await db.insert(
      'pricing_settings',
      settings.copyWith(updatedAt: DateTime.now()).toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Price of renting a car at [dailyRate] from [start] to [end] with the
  /// current grid.
  Future<PriceQuote> quote(
      double dailyRate, DateTime start, DateTime end) async {
    return PricingService.quote(
        dailyRate: dailyRate, start: start, end: end, settings: await get());
  }
}
