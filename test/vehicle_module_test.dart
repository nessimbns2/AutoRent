import 'dart:convert';
import 'dart:io';

import 'package:autorent/core/constants/business_rules.dart';
import 'package:autorent/core/database/database_helper.dart';
import 'package:autorent/core/notifications/notification_service.dart';
import 'package:autorent/core/services/image_storage.dart';
import 'package:autorent/core/services/vehicle_export_service.dart';
import 'package:autorent/core/utils/plate_formatter.dart';
import 'package:autorent/core/utils/validators.dart';
import 'package:autorent/models/enums.dart';
import 'package:autorent/models/vehicle.dart';
import 'package:autorent/models/vehicle_document.dart';
import 'package:autorent/repositories/rental_repository.dart';
import 'package:autorent/repositories/vehicle_document_repository.dart';
import 'package:autorent/repositories/vehicle_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Vehicle module (database v8): technical sheet, Tunisian plates, archiving,
/// administrative documents and the "no rental with expired insurance /
/// roadworthiness test" rule, alerts and exports.
///
/// Demo data used: Suzuki Swift (128 TUN 4521) has an expired roadworthiness
/// test, Škoda Fabia (215 TUN 7834) is rented and its insurance expires in
/// 5 days, Audi Q3 (240 TUN 2468) has valid documents.
void main() {
  // ── Pure rules ─────────────────────────────────────────────────────────────

  group('Tunisian plate', () {
    test('is formatted while typing', () {
      expect(TunisianPlateFormatter.format('123tun4567'), '123 TUN 4567');
      expect(TunisianPlateFormatter.format('1234567'), '123 TUN 4567');
      expect(TunisianPlateFormatter.format(' 12  tun 345 '), '12 TUN 345');
      expect(TunisianPlateFormatter.format('123 TUN 456789'), '123 TUN 4567');
    });

    test('is validated', () {
      expect(Validators.plate('123 TUN 4567'), isNull);
      expect(Validators.plate('9 TUN 1'), isNull);
      expect(Validators.plate('1234 TUN 1'), isNotNull);
      expect(Validators.plate('123 ABC 4567'), isNotNull);
      expect(Validators.plate(''), isNotNull);
    });
  });

  test('document status: valid / expiring within 30 days / expired / missing',
      () {
    final today = DateTime(2026, 11, 9);
    expect(BusinessRules.documentStatus(DateTime(2027, 3, 1), today),
        DocumentStatus.valid);
    expect(BusinessRules.documentStatus(DateTime(2026, 12, 9), today),
        DocumentStatus.expiringSoon);
    expect(BusinessRules.documentStatus(DateTime(2026, 11, 9), today),
        DocumentStatus.expiringSoon);
    expect(BusinessRules.documentStatus(DateTime(2026, 11, 8), today),
        DocumentStatus.expired);
    expect(BusinessRules.documentStatus(null, today), DocumentStatus.missing);
  });

  test('fleet CSV is Excel-friendly (BOM, ; separator, decimal comma)', () {
    final v = Vehicle(
      id: 7,
      brand: 'Peugeot',
      model: '208; GT',
      plate: '231 TUN 1056',
      pricePerDay: 90,
      createdAt: DateTime(2026),
      category: VehicleCategory.citadine,
      fuel: FuelType.essence,
      seats: 5,
    );
    final csv = VehicleExportService.buildFleetCsv([
      FleetCsvRow(
        vehicle: v,
        availability: 'Disponible',
        documents: {
          DocumentType.assurance: VehicleDocument(
              vehicleId: 7,
              type: DocumentType.assurance,
              expiresOn: DateTime(2027, 1, 31),
              updatedAt: DateTime(2026)),
        },
        rentals: 3,
        revenue: 1234.5,
      ),
    ]);
    expect(csv.startsWith('﻿ID;Marque;Modèle;'), isTrue);
    final line = csv.split('\r\n')[1];
    expect(line, contains('"208; GT"')); // separator inside a value is quoted
    expect(line, contains('90,000'));
    expect(line, contains('31/01/2027'));
    expect(line, endsWith(';3;1234,500'));
  });

  // ── Database ───────────────────────────────────────────────────────────────

  group('database v8', () {
    late Directory tempRoot;
    final repo = VehicleRepository();
    final docs = VehicleDocumentRepository();

    Future<int> idOf(String plate) async {
      final db = await DatabaseHelper.instance.database;
      final r = await db.query('vehicles',
          where: 'immatriculation = ?', whereArgs: [plate]);
      return r.first['id'] as int;
    }

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      tempRoot = Directory.systemTemp.createTempSync('autorent_vehicle_test_');
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

    test('demo cars get their technical sheet and 4 documents', () async {
      final q3 = (await repo.getById(await idOf('240 TUN 2468')))!;
      expect(q3.category, VehicleCategory.suv);
      expect(q3.fuel, FuelType.hybride);
      expect(q3.gearbox, Gearbox.automatique);
      expect(q3.mileage, 8900);
      expect(q3.archived, isFalse);
      expect(await docs.getByVehicle(q3.id!), hasLength(4));
    });

    test('expired roadworthiness test blocks the rental', () async {
      final swift = await idOf('128 TUN 4521');
      final q3 = await idOf('240 TUN 2468');
      final now = DateTime.now();

      expect(await repo.getAvailabilityState(swift),
          VehicleAvailability.documentsExpires);
      expect(await docs.blockingIssue(swift, now.add(const Duration(days: 3))),
          contains('visite technique est expirée'));
      expect(await docs.blockingIssue(q3, now.add(const Duration(days: 30))),
          isNull);

      // Not offered for a new rental…
      final free = await repo.getAvailableForRange(
          now.add(const Duration(days: 40)), now.add(const Duration(days: 42)));
      expect(free.any((v) => v.id == swift), isFalse);

      // …until the document is renewed.
      await docs.save(VehicleDocument(
        vehicleId: swift,
        type: DocumentType.visiteTechnique,
        expiresOn: now.add(const Duration(days: 365)),
        updatedAt: now,
      ));
      expect(await docs.blockingIssue(swift, now.add(const Duration(days: 3))),
          isNull);
      expect(await repo.getAvailabilityState(swift),
          isNot(VehicleAvailability.documentsExpires));
    });

    test('insurance expiring during the rental also blocks it', () async {
      final fabia = await idOf('215 TUN 7834'); // insurance ends in 5 days
      final issue = await docs.blockingIssue(
          fabia, DateTime.now().add(const Duration(days: 10)));
      expect(issue, contains("l'assurance expire le"));
    });

    test('extending a rental past the insurance date is refused', () async {
      final rentals = RentalRepository();
      final fabia = await idOf('215 TUN 7834');
      final running = (await rentals.getViewsByVehicle(fabia))
          .firstWhere((r) => r.rental.status == RentalStatus.enCours)
          .rental;
      expect(
        () => rentals.extend(
            running, running.endDate.add(const Duration(days: 10))),
        throwsA(predicate((e) => e.toString().contains('assurance'))),
      );
    });

    test('archiving hides the car, keeps its history, can be undone',
        () async {
      final q3 = await idOf('240 TUN 2468');
      // Booked / rented → archiving refused.
      expect(() => repo.archive(q3), throwsA(anything));

      final logan = await idOf('187 TUN 3390');
      final db = await DatabaseHelper.instance.database;
      await db.update('rentals', {'statut': 'terminee'},
          where: 'vehicle_id = ?', whereArgs: [logan]);
      await repo.archive(logan);

      expect((await repo.getById(logan))!.archived, isTrue);
      expect(await repo.getAvailabilityState(logan),
          VehicleAvailability.archivee);
      expect((await repo.getAll(includeArchived: false)).any((v) => v.id == logan),
          isFalse);
      expect((await repo.getAll(availableOnly: true)).any((v) => v.id == logan),
          isFalse);
      expect(await RentalRepository().getViewsByVehicle(logan), isNotEmpty);

      await repo.restore(logan);
      expect((await repo.getById(logan))!.archived, isFalse);
    });

    test('document alerts reach the notification center', () async {
      final alerts = await NotificationService.instance.refresh();
      final docAlerts = alerts.where((a) => a.id.startsWith('doc-')).toList();
      expect(
          docAlerts.any((a) =>
              a.level == AlertLevel.urgent &&
              a.title.contains('Visite technique expirée')),
          isTrue);
      expect(
          docAlerts.any((a) =>
              a.level == AlertLevel.today &&
              a.title.contains('Assurance expire dans 5 j')),
          isTrue);
    });

    test('vehicle PDF sheet is generated', () async {
      final id = await idOf('240 TUN 2468');
      final bytes = await VehicleExportService.buildVehicleSheet(
        VehicleSheetData(
          vehicle: (await repo.getById(id))!,
          availability: (await repo.getAvailabilityState(id)).label,
          stats: await repo.getStats(id),
          documents: await docs.getByVehicle(id),
          rentals: await RentalRepository().getViewsByVehicle(id),
          maintenances: const [],
          generatedAt: DateTime.now(),
        ),
      );
      expect(ascii.decode(bytes.sublist(0, 4)), '%PDF');
      expect(bytes.length, greaterThan(5000));
    });

    test('upgrading a v7 database adds the vehicle module', () async {
      var db = await DatabaseHelper.instance.database;
      await db.execute('DROP TABLE vehicle_documents');
      await db.setVersion(7);
      await DatabaseHelper.instance.close();

      db = await DatabaseHelper.instance.database; // runs onUpgrade 7 → 8
      expect(await db.getVersion(), DatabaseHelper.schemaVersion);
      expect(await db.query('vehicle_documents'), hasLength(24)); // 6 × 4
      final cols = {
        for (final r in await db.rawQuery('PRAGMA table_info(vehicles)'))
          r['name'],
      };
      expect(cols, containsAll(['categorie', 'kilometrage', 'archive']));
    });
  });
}
