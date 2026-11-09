import 'dart:io';

import 'package:autorent/core/database/database_helper.dart';
import 'package:autorent/core/services/image_storage.dart';
import 'package:autorent/models/enums.dart';
import 'package:autorent/models/rental.dart';
import 'package:autorent/repositories/rental_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Admin analytics: checks the figures on a small, fully known set of rentals
/// (the demo rentals are removed first).
void main() {
  late RentalRepository repo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await ImageStorage.init(
      directory: Directory.systemTemp.createTempSync('autorent_test_'),
    );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    // Own folder: test files run in parallel and must not share one DB file.
    await databaseFactory.setDatabasesPath(
        Directory.systemTemp.createTempSync('autorent_stats_db_').path);
  });

  setUp(() async {
    await DatabaseHelper.instance.close();
    await databaseFactory
        .deleteDatabase(join(await getDatabasesPath(), 'autorent.db'));
    final db = await DatabaseHelper.instance.database;
    await db.delete('incidents');
    await db.delete('rentals');
    repo = RentalRepository();
  });

  tearDownAll(() => DatabaseHelper.instance.close());

  Rental rental(String from, String to, double price, RentalStatus status) =>
      Rental(
        clientId: 1,
        vehicleId: 1,
        userId: 2,
        startDate: DateTime.parse(from),
        endDate: DateTime.parse(to),
        totalPrice: price,
        status: status,
        createdAt: DateTime(2026, 10, 1),
      );

  test('empty database gives zeros', () async {
    final s = await repo.getStats(now: DateTime(2026, 11, 9));
    expect(s.total, 0);
    expect(s.revenue, 0);
    expect(s.cancellationRate, 0);
    expect(s.monthly, hasLength(6));
    expect(s.topVehicles, isEmpty);
  });

  test('revenue ignores cancelled contracts and figures add up', () async {
    await repo.insert(
        rental('2026-11-01', '2026-11-03', 200, RentalStatus.terminee));
    await repo.insert(
        rental('2026-11-05', '2026-11-06', 100, RentalStatus.enCours));
    await repo.insert(
        rental('2026-11-07', '2026-11-08', 500, RentalStatus.annulee));
    await repo.insert(
        rental('2026-12-01', '2026-12-04', 300, RentalStatus.reservee));

    final s = await repo.getStats(now: DateTime(2026, 11, 9));

    expect(s.total, 4);
    expect(s.count(RentalStatus.annulee), 1);
    expect(s.cancellationRate, 0.25);
    expect(s.revenue, 600); // 200 + 100 + 300, the 500 is cancelled
    expect(s.averageAmount, 200);
    expect(s.averageDays, 2); // (2 + 1 + 3) / 3 days
    expect(s.revenueThisMonth, 300); // November: 200 + 100
    expect(s.overdue, 1); // running since 11-05, was due back 11-06
    expect(s.monthly.last.month, 11);
    expect(s.monthly.first.month, 6);
    expect(s.topVehicles.single.count, 3);
    expect(s.topVehicles.single.revenue, 600);
    expect(s.byAgent.single.count, 3);
  });
}
