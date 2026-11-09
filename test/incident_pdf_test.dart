import 'dart:io';

import 'package:autorent/features/incidents/incident_pdf.dart';
import 'package:autorent/models/enums.dart';
import 'package:autorent/models/incident.dart';
import 'package:autorent/models/incident_stats.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds a PDF incident report', () async {
    final out = Platform.environment['INCIDENT_PDF_OUT'];
    if (out != null) HttpOverrides.global = null; // allow real map tiles
    final now = DateTime(2026, 11, 8, 10, 30);
    final view = IncidentView(
      incident: Incident(
        id: 12,
        vehicleId: 2,
        rentalId: 5,
        reportedByUserId: 1,
        type: IncidentType.accident,
        date: now,
        place: 'Avenue Habib Bourguiba, Tunis',
        description: 'Choc arrière à un feu rouge. Pare-choc enfoncé.',
        status: IncidentStatus.enCours,
        createdAt: now,
        latitude: 36.8008,
        longitude: 10.1800,
      ),
      vehicleLabel: 'Škoda Fabia · 215 TUN 7834',
      reporterName: 'Sami Ben Ali',
      clientName: 'Karim Jaziri',
    );
    final history = [
      IncidentHistoryEntry(
        incidentId: 12,
        fromStatus: null,
        toStatus: IncidentStatus.enAttente,
        userName: 'Sami Ben Ali',
        changedAt: now,
      ),
      IncidentHistoryEntry(
        incidentId: 12,
        fromStatus: IncidentStatus.enAttente,
        toStatus: IncidentStatus.enCours,
        userName: 'AutoRent Administrateur',
        changedAt: now.add(const Duration(hours: 2)),
      ),
    ];
    final bytes = await buildIncidentPdf(view, history);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    if (out != null) await File(out).writeAsBytes(bytes);
  });
}
