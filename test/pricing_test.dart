import 'dart:io';

import 'package:autorent/core/database/database_helper.dart';
import 'package:autorent/core/services/image_storage.dart';
import 'package:autorent/core/services/pricing_service.dart';
import 'package:autorent/models/pricing_settings.dart';
import 'package:autorent/repositories/pricing_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pricing grid (database v9): long-stay discounts (−10 % from 7 days,
/// −25 % from 30 days), high season (+20 % from 1 July to 31 August) and
/// weekend rate (+10 % on Saturdays and Sundays).
///
/// Calendar used: Monday 9 November 2026, Wednesday 1 July 2026 and
/// Sunday 30 August 2026.
void main() {
  PriceQuote quote(DateTime start, DateTime end,
          {double rate = 100,
          PricingSettings settings = PricingSettings.defaults}) =>
      PricingService.quote(
          dailyRate: rate, start: start, end: end, settings: settings);

  group('price quote', () {
    test('every rule off: days × daily rate', () {
      final q = quote(DateTime(2026, 11, 9), DateTime(2026, 11, 14),
          settings: PricingSettings.flat);
      expect(q.days, 5);
      expect(q.total, 500);
      expect(q.isAdjusted, isFalse);
      expect(q.lines, hasLength(1));
      expect(q.summary, '5 j × 100 DT');
    });

    test('a weekend day costs 10 % more', () {
      // Mon 9 → Sun 15 (6 days): only Saturday 14 is billed as weekend.
      final q = quote(DateTime(2026, 11, 9), DateTime(2026, 11, 15));
      expect(q.weekendDays, 1);
      expect(q.weekendSurcharge, 10);
      expect(q.discount, 0);
      expect(q.total, 610);
    });

    test('−10 % from 7 days, applied after the weekend surcharge', () {
      final q = quote(DateTime(2026, 11, 9), DateTime(2026, 11, 16));
      expect(q.days, 7);
      expect(q.weekendDays, 2);
      expect(q.subtotal, 720);
      expect(q.discountPercent, 10);
      expect(q.discountFromDays, 7);
      expect(q.discount, 72);
      expect(q.total, 648);
      expect(q.lines.map((l) => l.kind), [
        PriceLineKind.base,
        PriceLineKind.weekend,
        PriceLineKind.discount,
      ]);
      expect(q.summary, '7 j · remise −10 % · week-end');
    });

    test('−25 % from 30 days (tiers are not cumulated)', () {
      final q = quote(DateTime(2026, 11, 9), DateTime(2026, 12, 9));
      expect(q.days, 30);
      expect(q.weekendDays, 8);
      expect(q.discountPercent, 25);
      expect(q.discountFromDays, 30);
      expect(q.total, 2310); // (3000 + 80) × 0.75
      expect(PricingSettings.defaults.longStayPercentFor(29), 10);
      expect(PricingSettings.defaults.longStayPercentFor(6), 0);
    });

    test('summer days cost 20 % more', () {
      // Wed 1 → Sat 4 July: Wed, Thu, Fri in high season, no weekend day.
      final q = quote(DateTime(2026, 7, 1), DateTime(2026, 7, 4));
      expect(q.seasonDays, 3);
      expect(q.weekendDays, 0);
      expect(q.total, 360);
    });

    test('season and weekend add up on the base rate, day by day', () {
      // Sun 30 Aug, Mon 31 Aug (season) and Tue 1 Sept (off season).
      final q = quote(DateTime(2026, 8, 30), DateTime(2026, 9, 2));
      expect(q.seasonDays, 2);
      expect(q.weekendDays, 1);
      expect(q.total, 350); // 300 + 2 × 20 + 1 × 10
    });

    test('same-day rental is billed one day', () {
      final q = quote(DateTime(2026, 11, 10), DateTime(2026, 11, 10));
      expect(q.days, 1);
      expect(q.total, 100);
    });

    test('amounts are rounded to the millime', () {
      final q = quote(DateTime(2026, 11, 9), DateTime(2026, 11, 16), rate: 85.5);
      expect(q.total, closeTo(554.04, 1e-9)); // (598.5 + 17.1) × 0.9
      expect((q.total * 1000) % 1, closeTo(0, 1e-6));
    });

    test('a negative weekend rate is a weekend discount', () {
      final q = quote(DateTime(2026, 11, 13), DateTime(2026, 11, 16),
          settings: PricingSettings.defaults.copyWith(weekendPercent: -10));
      expect(q.weekendSurcharge, -20);
      expect(q.total, 280);
      expect(q.lines.last.label, 'Week-end −10 %');
    });

    test('a season may span the new year', () {
      final s = PricingSettings.defaults.copyWith(
          seasonStartMonth: 12,
          seasonStartDay: 15,
          seasonEndMonth: 1,
          seasonEndDay: 15);
      expect(s.isHighSeason(DateTime(2026, 12, 20)), isTrue);
      expect(s.isHighSeason(DateTime(2027, 1, 15)), isTrue);
      expect(s.isHighSeason(DateTime(2027, 1, 16)), isFalse);
      expect(s.isHighSeason(DateTime(2026, 12, 14)), isFalse);
      expect(PricingSettings.defaults.isHighSeason(DateTime(2026, 8, 31)),
          isTrue);
      expect(PricingSettings.defaults.isHighSeason(DateTime(2026, 9, 1)),
          isFalse);
    });

    test('day count ignores daylight-saving changes', () {
      expect(PricingService.rentalDays(
          DateTime(2026, 3, 28), DateTime(2026, 3, 30)), 2);
      expect(PricingService.rentalDays(
          DateTime(2026, 10, 24), DateTime(2026, 10, 26)), 2);
    });

    test('settings survive a database round trip', () {
      final s = PricingSettings.defaults.copyWith(
          tier1Days: 5,
          tier1Percent: 12.5,
          seasonStartMonth: 6,
          seasonStartDay: 15,
          weekendEnabled: false);
      final back = PricingSettings.fromMap(s.toMap());
      expect(back.tier1Days, 5);
      expect(back.tier1Percent, 12.5);
      expect(back.seasonStartMonth, 6);
      expect(back.seasonStartDay, 15);
      expect(back.weekendEnabled, isFalse);
      expect(PricingService.signedPercent(12.5), '+12,5 %');
    });
  });

  group('database v9', () {
    late Directory tempRoot;
    final repo = PricingRepository();

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempRoot = Directory.systemTemp.createTempSync('autorent_pricing_test_');
      await ImageStorage.init(
          directory: Directory(join(tempRoot.path, 'photos')));
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfiNoIsolate;
      // Isolated folder: never touch the developer's app database.
      await databaseFactory.setDatabasesPath(join(tempRoot.path, 'databases'));
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await DatabaseHelper.instance.close();
      await databaseFactory
          .deleteDatabase(join(await getDatabasesPath(), 'autorent.db'));
    });

    tearDownAll(() async {
      await DatabaseHelper.instance.close();
      if (tempRoot.existsSync()) tempRoot.deleteSync(recursive: true);
    });

    test('a new database has the default grid', () async {
      final s = await repo.get();
      expect(s.tier1Days, 7);
      expect(s.tier1Percent, 10);
      expect(s.tier2Days, 30);
      expect(s.tier2Percent, 25);
      expect(s.seasonPercent, 20);
      expect((s.seasonStartMonth, s.seasonStartDay), (7, 1));
      expect((s.seasonEndMonth, s.seasonEndDay), (8, 31));
      expect(s.weekendPercent, 10);
      expect(s.updatedAt, isNotNull);
    });

    test('saved grid is used for the quotes', () async {
      await repo.save(PricingSettings.flat);
      final q = await repo.quote(
          100, DateTime(2026, 11, 9), DateTime(2026, 11, 16));
      expect(q.total, 700);

      await repo.save(PricingSettings.defaults.copyWith(tier1Percent: 15));
      final q2 = await repo.quote(
          100, DateTime(2026, 11, 9), DateTime(2026, 11, 16));
      expect(q2.total, 612); // 720 × 0.85
    });

    test('the database refuses an inconsistent grid', () async {
      await expectLater(
        repo.save(PricingSettings.defaults.copyWith(tier2Days: 5)),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repo.get()).tier2Days, 30); // unchanged
    });

    test('upgrading a v8 database adds the default grid', () async {
      var db = await DatabaseHelper.instance.database;
      await db.execute('DROP TABLE pricing_settings');
      await db.setVersion(8);
      await DatabaseHelper.instance.close();

      db = await DatabaseHelper.instance.database; // runs onUpgrade 8 → 9
      expect(await db.getVersion(), DatabaseHelper.schemaVersion);
      expect(await db.query('pricing_settings'), hasLength(1));
      expect((await repo.get()).tier2Percent, 25);
    });
  });
}
