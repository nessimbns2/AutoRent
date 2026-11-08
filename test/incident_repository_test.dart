import 'package:autorent/core/database/database_helper.dart';
import 'package:autorent/models/enums.dart';
import 'package:autorent/models/incident.dart';
import 'package:autorent/repositories/incident_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tests run against a real SQLite database (via sqflite FFI) created from the
/// app's schema + seed data, recreated before every test.
///
/// Seed used here: vehicle 1 = Peugeot 208, vehicle 4 = Volkswagen Golf,
/// rental 2 = Golf rented by "Trabelsi Mohamed" (en_cours), user 2 = agent.
void main() {
  late IncidentRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    await DatabaseHelper.instance.close();
    await databaseFactory
        .deleteDatabase(join(await getDatabasesPath(), 'autorent.db'));
    repo = IncidentRepository();
  });

  tearDownAll(() => DatabaseHelper.instance.close());

  Incident newIncident({
    int vehicleId = 1,
    int? rentalId,
    IncidentType type = IncidentType.panne,
    String place = 'Sousse',
    String description = 'Batterie à plat au démarrage',
    IncidentStatus status = IncidentStatus.enAttente,
    List<String> photos = const [],
  }) =>
      Incident(
        vehicleId: vehicleId,
        rentalId: rentalId,
        reportedByUserId: 2,
        type: type,
        date: DateTime(2026, 11, 1),
        place: place,
        description: description,
        status: status,
        createdAt: DateTime(2026, 11, 1, 9),
        photos: photos,
      );

  test('insert then getById returns the same data, photos in order', () async {
    final id = await repo.insert(newIncident(photos: ['a.jpg', 'b.jpg']));
    final inc = await repo.getById(id);

    expect(inc, isNotNull);
    expect(inc!.vehicleId, 1);
    expect(inc.type, IncidentType.panne);
    expect(inc.place, 'Sousse');
    expect(inc.status, IncidentStatus.enAttente);
    expect(inc.date, DateTime(2026, 11, 1));
    expect(inc.photos, ['a.jpg', 'b.jpg']);
  });

  test('update replaces fields and the photo list', () async {
    final id = await repo.insert(newIncident(photos: ['a.jpg', 'b.jpg']));
    final inc = (await repo.getById(id))!;

    await repo.update(inc.copyWith(
      type: IncidentType.accident,
      place: 'Tunis',
      status: IncidentStatus.enCours,
      photos: ['c.jpg'],
    ));

    final updated = (await repo.getById(id))!;
    expect(updated.type, IncidentType.accident);
    expect(updated.place, 'Tunis');
    expect(updated.status, IncidentStatus.enCours);
    expect(updated.photos, ['c.jpg']);
  });

  test('changeStatus moves through en_attente -> en_cours -> resolu', () async {
    final id = await repo.insert(newIncident());

    await repo.changeStatus(id, IncidentStatus.enCours);
    expect((await repo.getById(id))!.status, IncidentStatus.enCours);

    await repo.changeStatus(id, IncidentStatus.resolu);
    expect((await repo.getById(id))!.status, IncidentStatus.resolu);
  });

  test('delete removes the incident', () async {
    final id = await repo.insert(newIncident());
    await repo.delete(id);
    expect(await repo.getById(id), isNull);
  });

  test('getViewById includes vehicle, reporter and renter names', () async {
    final id = await repo.insert(newIncident(vehicleId: 4, rentalId: 2));
    final view = (await repo.getViewById(id))!;

    expect(view.vehicleLabel, contains('Golf'));
    expect(view.reporterName, 'Ben Ali Sami');
    expect(view.clientName, 'Trabelsi Mohamed');
  });

  test('getViewById has no renter when no rental is linked', () async {
    final id = await repo.insert(newIncident());
    expect((await repo.getViewById(id))!.clientName, isNull);
  });

  group('getViews filters', () {
    late int panneId;
    late int accidentId;

    setUp(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('incidents'); // ignore seeded incidents
      panneId = await repo.insert(newIncident(
        place: 'Sousse',
        description: 'Moteur qui chauffe sur autoroute',
      ));
      accidentId = await repo.insert(newIncident(
        vehicleId: 4,
        rentalId: 2,
        type: IncidentType.accident,
        place: 'Tunis',
        description: 'Choc arrière au feu rouge',
        status: IncidentStatus.enCours,
      ));
    });

    List<int> ids(List<IncidentView> views) =>
        [for (final v in views) v.incident.id!];

    test('by status', () async {
      expect(ids(await repo.getViews(status: IncidentStatus.enAttente)),
          [panneId]);
      expect(ids(await repo.getViews(status: IncidentStatus.enCours)),
          [accidentId]);
      expect(await repo.getViews(status: IncidentStatus.resolu), isEmpty);
    });

    test('by type', () async {
      expect(ids(await repo.getViews(type: IncidentType.accident)),
          [accidentId]);
      expect(ids(await repo.getViews(type: IncidentType.panne)), [panneId]);
    });

    test('search by place, description, vehicle, plate and renter', () async {
      expect(ids(await repo.getViews(query: 'sousse')), [panneId]);
      expect(ids(await repo.getViews(query: 'feu rouge')), [accidentId]);
      expect(ids(await repo.getViews(query: 'golf')), [accidentId]);
      expect(ids(await repo.getViews(query: '123 TUN')), [panneId]);
      expect(ids(await repo.getViews(query: 'Mohamed Trabelsi')),
          [accidentId]);
      expect(await repo.getViews(query: 'introuvable'), isEmpty);
    });

    test('search treats % and _ literally', () async {
      expect(await repo.getViews(query: '%'), isEmpty);
      expect(await repo.getViews(query: '_'), isEmpty);
    });

    test('filters combine', () async {
      expect(
          await repo.getViews(
              status: IncidentStatus.enAttente, type: IncidentType.accident),
          isEmpty);
    });

    test('countByStatus reports every status', () async {
      expect(await repo.countByStatus(), {
        IncidentStatus.enAttente: 1,
        IncidentStatus.enCours: 1,
        IncidentStatus.resolu: 0,
      });
    });
  });
}
