import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/services/image_storage.dart';
import '../../core/utils/formatters.dart';
import '../../models/enums.dart';
import '../../models/incident.dart';
import '../../models/incident_stats.dart';

/// Builds the incident report (constat) and opens the system sheet to save
/// it to the phone, or share it (WhatsApp, email, Drive...).
Future<void> shareIncidentPdf(
  IncidentView view,
  List<IncidentHistoryEntry> history,
) async {
  final bytes = await buildIncidentPdf(view, history);
  await Printing.sharePdf(
    bytes: bytes,
    filename: 'incident-${view.incident.id}.pdf',
  );
}

const _brand = PdfColor.fromInt(0xFFFF6B2C);
const _ink = PdfColor.fromInt(0xFF0F172A);
const _muted = PdfColor.fromInt(0xFF64748B);
const _border = PdfColor.fromInt(0xFFE2E8F0);
const _soft = PdfColor.fromInt(0xFFF8FAFC);

PdfColor _statusColor(IncidentStatus s) => switch (s) {
  IncidentStatus.enAttente => const PdfColor.fromInt(0xFFEF4444),
  IncidentStatus.enCours => const PdfColor.fromInt(0xFF3B82F6),
  IncidentStatus.resolu => const PdfColor.fromInt(0xFF22C55E),
};

PdfColor _typeColor(IncidentType t) => t == IncidentType.accident
    ? const PdfColor.fromInt(0xFFEF4444)
    : const PdfColor.fromInt(0xFFF59E0B);

String _dateTime(DateTime d) =>
    '${formatDate(d)} à ${DateFormat('HH:mm').format(d)}';

Future<Uint8List> buildIncidentPdf(
  IncidentView view,
  List<IncidentHistoryEntry> history,
) async {
  final inc = view.incident;
  final font = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
  );
  final bold = pw.Font.ttf(
    await rootBundle.load('assets/fonts/Poppins-Bold.ttf'),
  );
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: font, bold: bold),
    title: '${inc.type.label} #${inc.id}',
    author: 'AutoRent',
  );

  final photos = <pw.MemoryImage>[];
  for (final name in inc.photos) {
    try {
      final f = ImageStorage.fileFor(name);
      if (await f.exists()) photos.add(pw.MemoryImage(await f.readAsBytes()));
    } catch (_) {
      // Missing photo file: skip it.
    }
  }

  final map = inc.hasPosition
      ? await _mapSnapshot(inc.latitude!, inc.longitude!)
      : null;

  pw.Widget sectionTitle(String t) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 18, bottom: 8),
    child: pw.Row(
      children: [
        pw.Container(width: 4, height: 14, color: _brand),
        pw.SizedBox(width: 8),
        pw.Text(
          t.toUpperCase(),
          style: pw.TextStyle(
            font: bold,
            fontSize: 10.5,
            color: _ink,
            letterSpacing: 0.8,
          ),
        ),
      ],
    ),
  );

  pw.Widget chip(String label, PdfColor color) => pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: pw.BoxDecoration(
      color: color,
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Text(
      label,
      style: pw.TextStyle(font: bold, fontSize: 9, color: PdfColors.white),
    ),
  );

  pw.Widget info(String k, String v) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 130,
          child: pw.Text(
            k,
            style: const pw.TextStyle(fontSize: 10, color: _muted),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            v,
            style: pw.TextStyle(font: bold, fontSize: 10, color: _ink),
          ),
        ),
      ],
    ),
  );

  pw.Widget box(List<pw.Widget> children) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: pw.BoxDecoration(
      color: _soft,
      border: pw.Border.all(color: _border),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: children,
    ),
  );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Text(
                'AutoRent · ${inc.type.label} #${inc.id}',
                style: const pw.TextStyle(fontSize: 9, color: _muted),
              ),
            ),
      footer: (ctx) => pw.Container(
        margin: const pw.EdgeInsets.only(top: 12),
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: _border)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Généré le ${_dateTime(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8.5, color: _muted),
            ),
            pw.Text(
              'Page ${ctx.pageNumber} / ${ctx.pagesCount}',
              style: const pw.TextStyle(fontSize: 8.5, color: _muted),
            ),
          ],
        ),
      ),
      build: (ctx) => [
        // Header band
        pw.Container(
          padding: const pw.EdgeInsets.all(18),
          decoration: pw.BoxDecoration(
            color: _ink,
            borderRadius: pw.BorderRadius.circular(10),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'AutoRent',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 13,
                        color: _brand,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      "Rapport d'incident n° ${inc.id}",
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 20,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      view.vehicleLabel,
                      style: const pw.TextStyle(
                        fontSize: 10.5,
                        color: PdfColors.grey300,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  chip(inc.type.label, _typeColor(inc.type)),
                  pw.SizedBox(height: 6),
                  chip(inc.status.label, _statusColor(inc.status)),
                ],
              ),
            ],
          ),
        ),

        sectionTitle('Informations'),
        box([
          info('Type', inc.type.label),
          info('Date de l\'incident', formatDate(inc.date)),
          info('Lieu', inc.place),
          if (inc.hasPosition)
            info(
              'Coordonnées GPS',
              '${inc.latitude!.toStringAsFixed(5)}, '
                  '${inc.longitude!.toStringAsFixed(5)}',
            ),
          info('Statut actuel', inc.status.label),
          info('Déclaré par', view.reporterName ?? '—'),
          info('Déclaré le', _dateTime(inc.createdAt)),
        ]),

        sectionTitle('Véhicule & location'),
        box([
          info('Véhicule', view.vehicleLabel),
          info(
            'Location',
            inc.rentalId == null ? 'Aucune location liée' : 'n° ${inc.rentalId}',
          ),
          if (view.clientName != null) info('Locataire', view.clientName!),
        ]),

        sectionTitle('Description'),
        box([
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Text(
              inc.description.trim().isEmpty
                  ? 'Aucune description.'
                  : inc.description.trim(),
              style: const pw.TextStyle(
                fontSize: 10.5,
                color: _ink,
                lineSpacing: 3,
              ),
            ),
          ),
        ]),

        if (map != null)
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                sectionTitle('Localisation'),
                map,
                pw.SizedBox(height: 4),
                pw.Text(
                  '© contributeurs OpenStreetMap',
                  style: const pw.TextStyle(fontSize: 7.5, color: _muted),
                ),
              ],
            ),
          ),

        if (photos.isNotEmpty) ...[
          sectionTitle('Photos (${photos.length})'),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final img in photos)
                pw.ClipRRect(
                  horizontalRadius: 6,
                  verticalRadius: 6,
                  child: pw.Image(
                    img,
                    width: 168,
                    height: 120,
                    fit: pw.BoxFit.cover,
                  ),
                ),
            ],
          ),
        ],

        if (history.isNotEmpty) ...[
          sectionTitle('Historique des statuts'),
          pw.Table(
            border: pw.TableBorder.all(color: _border),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.2),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(2.2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _soft),
                children: [
                  for (final h in const ['Date', 'Changement', 'Par'])
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(
                        h,
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 9.5,
                          color: _ink,
                        ),
                      ),
                    ),
                ],
              ),
              for (final e in history)
                pw.TableRow(
                  children: [
                    _cell(_dateTime(e.changedAt)),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(7),
                      child: pw.Text(
                        e.isDeclaration
                            ? 'Déclaré (${e.toStatus.label})'
                            : '${e.fromStatus!.label}  >  ${e.toStatus.label}',
                        style: pw.TextStyle(
                          font: bold,
                          fontSize: 9.5,
                          color: _statusColor(e.toStatus),
                        ),
                      ),
                    ),
                    _cell(e.userName ?? '—'),
                  ],
                ),
            ],
          ),
        ],

        pw.SizedBox(height: 36),
        pw.Row(
          children: [
            pw.Expanded(child: _signature('Signature du déclarant')),
            pw.SizedBox(width: 30),
            pw.Expanded(child: _signature("Signature de l'agence")),
          ],
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _cell(String t) => pw.Padding(
  padding: const pw.EdgeInsets.all(7),
  child: pw.Text(t, style: const pw.TextStyle(fontSize: 9.5, color: _ink)),
);

pw.Widget _signature(String label) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.SizedBox(height: 40),
    pw.Container(height: 1, color: _muted),
    pw.SizedBox(height: 4),
    pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: _muted)),
  ],
);

/// A small static map around the point, assembled from OpenStreetMap tiles.
/// Returns null when offline so the report still builds.
Future<pw.Widget?> _mapSnapshot(double lat, double lng) async {
  const zoom = 16;
  const tile = 128.0; // points per tile in the PDF
  const width = 523.0, height = 190.0; // viewport, pin in the middle
  final n = math.pow(2, zoom).toDouble();
  final xf = (lng + 180) / 360 * n;
  final latRad = lat * math.pi / 180;
  final yf =
      (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) /
      2 *
      n;
  final x0 = (xf - width / 2 / tile).floor();
  final y0 = (yf - height / 2 / tile).floor();
  final cols = (width / tile).ceil() + 1;
  final rows = (height / tile).ceil() + 1;
  // Shift the tile grid so the incident point lands at the viewport centre.
  final ox = width / 2 - (xf - x0) * tile;
  final oy = height / 2 - (yf - y0) * tile;

  const headers = {
    'User-Agent': 'AutoRent/1.0 (ESPRIT student project, Flutter)',
  };
  try {
    final futures = <Future<http.Response>>[
      for (var r = 0; r < rows; r++)
        for (var c = 0; c < cols; c++)
          http
              .get(
                Uri.parse(
                  'https://tile.openstreetmap.org/$zoom/${x0 + c}/${y0 + r}.png',
                ),
                headers: headers,
              )
              .timeout(const Duration(seconds: 6)),
    ];
    final responses = await Future.wait(futures);
    if (responses.any((r) => r.statusCode != 200)) return null;

    const pin = 22.0;

    return pw.ClipRRect(
      horizontalRadius: 8,
      verticalRadius: 8,
      child: pw.SizedBox(
        width: width,
        height: height,
        child: pw.Stack(
          children: [
            for (var r = 0; r < rows; r++)
              for (var c = 0; c < cols; c++)
                pw.Positioned(
                  left: ox + c * tile,
                  top: oy + r * tile,
                  child: pw.Image(
                    pw.MemoryImage(responses[r * cols + c].bodyBytes),
                    width: tile,
                    height: tile,
                  ),
                ),
            pw.Positioned(
              left: width / 2 - pin / 2,
              top: height / 2 - pin / 2,
              child: pw.Container(
                width: pin,
                height: pin,
                decoration: pw.BoxDecoration(
                  color: _brand,
                  shape: pw.BoxShape.circle,
                  border: pw.Border.all(color: PdfColors.white, width: 3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  } catch (_) {
    return null;
  }
}
