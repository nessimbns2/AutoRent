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
    await databaseFactory.deleteDatabase(
      join(await getDatabasesPath(), 'autorent.db'),
    );
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
  }) => Incident(
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

    await repo.update(
      inc.copyWith(
        type: IncidentType.accident,
        place: 'Tunis',
        status: IncidentStatus.enCours,
        photos: ['c.jpg'],
      ),
    );

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

  group('status history', () {
    test('insert records the declaration by the reporting user', () async {
      final id = await repo.insert(newIncident());
      final h = await repo.getHistory(id);
      expect(h, hasLength(1));
      expect(h.single.isDeclaration, isTrue);
      expect(h.single.toStatus, IncidentStatus.enAttente);
      expect(h.single.userName, 'Ben Ali Sami');
      expect(h.single.changedAt, DateTime(2026, 11, 1, 9));
    });

    test(
      'changeStatus records from/to and who; same status is ignored',
      () async {
        final id = await repo.insert(newIncident());
        await repo.changeStatus(id, IncidentStatus.enCours, byUserId: 1);
        await repo.changeStatus(id, IncidentStatus.enCours, byUserId: 1);
        await repo.changeStatus(id, IncidentStatus.resolu, byUserId: 2);

        final h = await repo.getHistory(id);
        expect(
          [for (final e in h) e.toStatus],
          [
            IncidentStatus.enAttente,
            IncidentStatus.enCours,
            IncidentStatus.resolu,
          ],
        );
        expect(h[1].fromStatus, IncidentStatus.enAttente);
        expect(h[1].userName, 'Administrateur AutoRent');
        expect(h[2].fromStatus, IncidentStatus.enCours);
        expect(h[2].userName, 'Ben Ali Sami');
      },
    );

    test('update logs only when the status changes', () async {
      final id = await repo.insert(newIncident());
      final inc = (await repo.getById(id))!;
      await repo.update(inc.copyWith(place: 'Bizerte'), byUserId: 1);
      expect(await repo.getHistory(id), hasLength(1));

      await repo.update(
        inc.copyWith(status: IncidentStatus.resolu),
        byUserId: 1,
      );
      final h = await repo.getHistory(id);
      expect(h, hasLength(2));
      expect(h.last.fromStatus, IncidentStatus.enAttente);
      expect(h.last.toStatus, IncidentStatus.resolu);
    });

    test('deleting an incident deletes its history', () async {
      final id = await repo.insert(newIncident());
      await repo.changeStatus(id, IncidentStatus.enCours, byUserId: 1);
      await repo.delete(id);
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM incident_history WHERE incident_id = ?',
        [id],
      );
      final n = rows.first['n'] as int;
      expect(n, 0);
    });

    test('demo data: 7 incidents, each with a coherent history', () async {
      final views = await repo.getViews();
      expect(views, hasLength(7));
      for (final v in views) {
        final h = await repo.getHistory(v.incident.id!);
        expect(h, isNotEmpty);
        expect(h.first.isDeclaration, isTrue);
        expect(
          h.last.toStatus,
          v.incident.status,
          reason: 'history must end on the current status',
        );
        for (var i = 1; i < h.length; i++) {
          expect(h[i].fromStatus, h[i - 1].toStatus);
          expect(h[i].changedAt.isBefore(h[i - 1].changedAt), isFalse);
        }
      }
      final stats = await repo.getStats();
      expect(stats.byStatus.values.every((n) => n > 0), isTrue);
      expect(stats.byType.values.every((n) => n > 0), isTrue);
    });

    test('upgrading a v1 database creates and backfills the history', () async {
      // Turn the fresh database back into a v1 one.
      var db = await DatabaseHelper.instance.database;
      await db.execute('DROP TABLE incident_history');
      await db.setVersion(1);
      await DatabaseHelper.instance.close();

      db = await DatabaseHelper.instance.database; // runs onUpgrade 1 → 2
      expect(await db.getVersion(), 2);
      // One "declared" entry per existing incident, in its current status.
      final rows = await db.rawQuery('''
        SELECT h.from_statut, h.to_statut = i.statut AS same
        FROM incident_history h JOIN incidents i ON i.id = h.incident_id
      ''');
      final incidents = await db.query('incidents');
      expect(rows, hasLength(incidents.length));
      expect(
        rows.every((r) => r['from_statut'] == null && r['same'] == 1),
        isTrue,
      );
    });
  });

  group('getStats', () {
    setUp(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('incidents'); // history cascades
    });

    test('empty database', () async {
      final s = await repo.getStats();
      expect(s.total, 0);
      expect(s.open, 0);
      expect(s.resolutionRate, 0);
      expect(s.averageResolution, isNull);
      expect(s.topVehicles, isEmpty);
      expect(s.recentActivity, isEmpty);
    });

    test('counts, rate, average resolution, top vehicles, activity', () async {
      final now = DateTime.now();
      final a = await repo.insert(
        newIncident(vehicleId: 4).copyWith(
          type: IncidentType.accident,
          createdAt: now.subtract(const Duration(hours: 48)),
        ),
      );
      await repo.insert(
        newIncident(vehicleId: 4)
            .copyWith(createdAt: now.subtract(const Duration(hours: 1))),
      );
      final c = await repo.insert(
        newIncident(vehicleId: 1)
            .copyWith(createdAt: now.subtract(const Duration(days: 40))),
      );
      await repo.changeStatus(a, IncidentStatus.resolu, byUserId: 1);
      await repo.changeStatus(c, IncidentStatus.enCours, byUserId: 2);

      final s = await repo.getStats(now: now);
      expect(s.total, 3);
      expect(s.byStatus[IncidentStatus.enAttente], 1);
      expect(s.byStatus[IncidentStatus.enCours], 1);
      expect(s.byStatus[IncidentStatus.resolu], 1);
      expect(s.open, 2);
      expect(s.byType[IncidentType.accident], 1);
      expect(s.byType[IncidentType.panne], 2);
      expect(s.last30Days, 2);
      expect(s.resolutionRate, closeTo(1 / 3, 1e-9));
      expect(s.averageResolution!.inMinutes, closeTo(48 * 60, 2));
      expect(s.topVehicles.first.vehicleId, 4);
      expect(s.topVehicles.first.count, 2);
      // Most recent first: the two status changes, then declarations.
      expect(s.recentActivity.first.entry.incidentId, c);
      expect(s.recentActivity.first.entry.toStatus, IncidentStatus.enCours);
      expect(s.recentActivity.length, 5);
    });
  });

  group('getViews filters', () {
    late int panneId;
    late int accidentId;

    setUp(() async {
      final db = await DatabaseHelper.instance.database;
      await db.delete('incidents'); // ignore seeded incidents
      panneId = await repo.insert(
        newIncident(
          place: 'Sousse',
          description: 'Moteur qui chauffe sur autoroute',
        ),
      );
      accidentId = await repo.insert(
        newIncident(
          vehicleId: 4,
          rentalId: 2,
          type: IncidentType.accident,
          place: 'Tunis',
          description: 'Choc arrière au feu rouge',
          status: IncidentStatus.enCours,
        ),
      );
    });

    List<int> ids(List<IncidentView> views) => [
      for (final v in views) v.incident.id!,
    ];

    test('by status', () async {
      expect(ids(await repo.getViews(status: IncidentStatus.enAttente)), [
        panneId,
      ]);
      expect(ids(await repo.getViews(status: IncidentStatus.enCours)), [
        accidentId,
      ]);
      expect(await repo.getViews(status: IncidentStatus.resolu), isEmpty);
    });

    test('by type', () async {
      expect(ids(await repo.getViews(type: IncidentType.accident)), [
        accidentId,
      ]);
      expect(ids(await repo.getViews(type: IncidentType.panne)), [panneId]);
    });

    test('search by place, description, vehicle, plate and renter', () async {
      expect(ids(await repo.getViews(query: 'sousse')), [panneId]);
      expect(ids(await repo.getViews(query: 'feu rouge')), [accidentId]);
      expect(ids(await repo.getViews(query: 'golf')), [accidentId]);
      expect(ids(await repo.getViews(query: '123 TUN')), [panneId]);
      expect(ids(await repo.getViews(query: 'Mohamed Trabelsi')), [accidentId]);
      expect(await repo.getViews(query: 'introuvable'), isEmpty);
    });

    test('search treats % and _ literally', () async {
      expect(await repo.getViews(query: '%'), isEmpty);
      expect(await repo.getViews(query: '_'), isEmpty);
    });

    test('filters combine', () async {
      expect(
        await repo.getViews(
          status: IncidentStatus.enAttente,
          type: IncidentType.accident,
        ),
        isEmpty,
      );
    });

    test('recentPlaces lists distinct places, newest first', () async {
      await repo.insert(
        newIncident(place: 'sousse').copyWith(createdAt: DateTime(2026, 11, 5)),
      ); // same place, other case
      expect(await repo.recentPlaces(), ['sousse', 'Tunis']);
      expect(await repo.recentPlaces(limit: 1), hasLength(1));
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
