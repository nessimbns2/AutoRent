import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/maintenance.dart';
import '../../models/rental.dart';
import '../../models/vehicle.dart';
import '../../models/vehicle_document.dart';
import '../../repositories/vehicle_repository.dart';
import '../constants/business_rules.dart';
import '../utils/formatters.dart';

/// Everything printed on the vehicle sheet.
class VehicleSheetData {
  final Vehicle vehicle;
  final String availability;
  final VehicleStats stats;
  final Map<DocumentType, VehicleDocument> documents;
  final List<RentalView> rentals;
  final List<Maintenance> maintenances;
  final Uint8List? photo;
  final DateTime generatedAt;

  const VehicleSheetData({
    required this.vehicle,
    required this.availability,
    required this.stats,
    required this.documents,
    required this.rentals,
    required this.maintenances,
    required this.generatedAt,
    this.photo,
  });
}

/// One line of the fleet CSV export.
class FleetCsvRow {
  final Vehicle vehicle;
  final String availability;
  final Map<DocumentType, VehicleDocument> documents;
  final int rentals;
  final double revenue;
  const FleetCsvRow({
    required this.vehicle,
    required this.availability,
    required this.documents,
    required this.rentals,
    required this.revenue,
  });
}

/// Builders for the vehicle exports (no UI, so they can be unit tested).
class VehicleExportService {
  VehicleExportService._();

  // ── CSV ────────────────────────────────────────────────────────────────────

  static const csvHeaders = [
    'ID',
    'Marque',
    'Modèle',
    'Immatriculation',
    'Catégorie',
    'Carburant',
    'Boîte',
    'Places',
    'Année',
    'Couleur',
    'Kilométrage',
    'Prix/jour (DT)',
    'État',
    'Mise en location',
    'Archivé',
    'Assurance',
    'Visite technique',
    'Vignette',
    'Carte grise',
    'Locations',
    'Revenu (DT)',
  ];

  /// Fleet as CSV for Excel (French settings): `;` separator, decimal comma,
  /// UTF-8 with BOM so accents display correctly, CRLF line endings.
  static String buildFleetCsv(List<FleetCsvRow> rows) {
    String cell(Object? v) {
      final s = v?.toString() ?? '';
      return s.contains(RegExp('[;"\n\r]'))
          ? '"${s.replaceAll('"', '""')}"'
          : s;
    }

    String money(double v) => v.toStringAsFixed(3).replaceAll('.', ',');
    String doc(Map<DocumentType, VehicleDocument> d, DocumentType t) =>
        d[t] == null ? '' : formatDate(d[t]!.expiresOn);

    final lines = <String>[csvHeaders.map(cell).join(';')];
    for (final r in rows) {
      final v = r.vehicle;
      lines.add(
        [
          v.id,
          v.brand,
          v.model,
          v.plate,
          v.category?.label,
          v.fuel?.label,
          v.gearbox?.label,
          v.seats,
          v.year,
          v.color,
          v.mileage,
          money(v.pricePerDay),
          r.availability,
          v.available ? 'Oui' : 'Non',
          v.archived ? 'Oui' : 'Non',
          doc(r.documents, DocumentType.assurance),
          doc(r.documents, DocumentType.visiteTechnique),
          doc(r.documents, DocumentType.vignette),
          doc(r.documents, DocumentType.carteGrise),
          r.rentals,
          money(r.revenue),
        ].map(cell).join(';'),
      );
    }
    return '﻿${lines.join('\r\n')}\r\n';
  }

  static Uint8List csvBytes(String csv) => Uint8List.fromList(utf8.encode(csv));

  // ── PDF ────────────────────────────────────────────────────────────────────

  static final _navy = PdfColor.fromInt(0xFF0E1726);
  static final _brand = PdfColor.fromInt(0xFFFF6B2C);
  static final _muted = PdfColor.fromInt(0xFF6B7385);
  static final _soft = PdfColor.fromInt(0xFFF4F6FA);

  static PdfColor _docColor(DocumentStatus s) => switch (s) {
    DocumentStatus.valid => PdfColor.fromInt(0xFF16A34A),
    DocumentStatus.expiringSoon => PdfColor.fromInt(0xFFF59E0B),
    DocumentStatus.expired => PdfColor.fromInt(0xFFEF4444),
    DocumentStatus.missing => _muted,
  };

  /// A4 vehicle sheet: identity, photo, technical sheet, documents with
  /// their status, activity and the latest rentals / maintenance.
  static Future<Uint8List> buildVehicleSheet(VehicleSheetData d) async {
    final font = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Poppins-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/Poppins-Bold.ttf'),
    );
    final v = d.vehicle;
    final doc = pw.Document(
      title: 'Fiche véhicule ${v.plate}',
      author: 'AutoRent',
      theme: pw.ThemeData.withFont(base: font, bold: bold),
    );

    pw.Widget section(String title) => pw.Padding(
      padding: const pw.EdgeInsets.only(top: 16, bottom: 8),
      child: pw.Row(
        children: [
          pw.Container(width: 4, height: 14, color: _brand),
          pw.SizedBox(width: 6),
          pw.Text(
            title,
            style: pw.TextStyle(font: bold, fontSize: 12, color: _navy),
          ),
        ],
      ),
    );

    pw.Widget kv(String k, String? val) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _soft, width: 1)),
      ),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(k, style: pw.TextStyle(fontSize: 9, color: _muted)),
          ),
          pw.Text(
            val == null || val.isEmpty ? '—' : val,
            style: pw.TextStyle(font: bold, fontSize: 9.5),
          ),
        ],
      ),
    );

    pw.Widget stat(String label, String value) => pw.Expanded(
      child: pw.Container(
        margin: const pw.EdgeInsets.only(right: 6),
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: _soft,
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              value,
              style: pw.TextStyle(font: bold, fontSize: 13, color: _navy),
            ),
            pw.Text(label, style: pw.TextStyle(fontSize: 8, color: _muted)),
          ],
        ),
      ),
    );

    final specs = <(String, String?)>[
      ('Catégorie', v.category?.label),
      ('Carburant', v.fuel?.label),
      ('Boîte de vitesses', v.gearbox?.label),
      ('Places', v.seats?.toString()),
      ('Année', v.year?.toString()),
      ('Couleur', v.color),
      (
        'Kilométrage',
        v.mileage == null
            ? null
            : '${v.mileage.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ' ')} km',
      ),
      ('Tarif journalier', formatMoney(v.pricePerDay)),
      ('Mise en location', v.available ? 'Activée' : 'Désactivée'),
      ('Ajouté le', formatDate(v.createdAt)),
    ];
    final half = (specs.length / 2).ceil();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 28),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Text(
                '${v.brand} ${v.model} · ${v.plate}',
                style: pw.TextStyle(fontSize: 8, color: _muted),
              ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Fiche générée par AutoRent le ${formatDate(d.generatedAt)}',
              style: pw.TextStyle(fontSize: 8, color: _muted),
            ),
            pw.Text(
              'Page ${ctx.pageNumber}/${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 8, color: _muted),
            ),
          ],
        ),
        build: (ctx) => [
          // Header band
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: pw.BoxDecoration(
              color: _navy,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      'Auto',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 18,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.Text(
                      'Rent',
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 18,
                        color: _brand,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  'FICHE VÉHICULE',
                  style: pw.TextStyle(
                    font: bold,
                    fontSize: 10,
                    color: PdfColors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      v.brand.toUpperCase(),
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 9,
                        color: _brand,
                        letterSpacing: 1,
                      ),
                    ),
                    pw.Text(
                      v.model,
                      style: pw.TextStyle(
                        font: bold,
                        fontSize: 22,
                        color: _navy,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: _navy, width: 1.2),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        v.plate,
                        style: pw.TextStyle(font: bold, fontSize: 11),
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      v.archived
                          ? 'Archivé${v.archivedAt == null ? '' : ' le ${formatDate(v.archivedAt!)}'}'
                          : 'État actuel : ${d.availability}',
                      style: pw.TextStyle(fontSize: 9, color: _muted),
                    ),
                  ],
                ),
              ),
              if (d.photo != null)
                pw.Container(
                  width: 220,
                  height: 130,
                  decoration: pw.BoxDecoration(
                    color: _soft,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.ClipRRect(
                    horizontalRadius: 8,
                    verticalRadius: 8,
                    child: pw.Image(
                      pw.MemoryImage(d.photo!),
                      fit: pw.BoxFit.cover,
                    ),
                  ),
                ),
            ],
          ),

          section('Caractéristiques'),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [for (final s in specs.take(half)) kv(s.$1, s.$2)],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(
                child: pw.Column(
                  children: [for (final s in specs.skip(half)) kv(s.$1, s.$2)],
                ),
              ),
            ],
          ),

          section('Documents administratifs'),
          pw.TableHelper.fromTextArray(
            headers: ['Document', 'N°', 'Échéance', 'Statut'],
            headerStyle: pw.TextStyle(
              font: bold,
              fontSize: 9,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: _navy),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 5,
            ),
            oddRowDecoration: pw.BoxDecoration(color: _soft),
            border: null,
            data: [
              for (final t in DocumentType.values)
                [
                  '${t.label}${t.blocksRental ? ' *' : ''}',
                  d.documents[t]?.number ?? '—',
                  d.documents[t] == null
                      ? '—'
                      : formatDate(d.documents[t]!.expiresOn),
                  BusinessRules.documentStatus(d.documents[t]?.expiresOn).label,
                ],
            ],
            // Colour the "Statut" column; rowNum counts the header row.
            cellBuilder: (col, value, rowNum) => col == 3 && rowNum >= 1
                ? pw.Text(
                    '$value',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 9,
                      color: _docColor(
                        BusinessRules.documentStatus(
                          d
                              .documents[DocumentType.values[rowNum - 1]]
                              ?.expiresOn,
                        ),
                      ),
                    ),
                  )
                : null,
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(
              '* Obligatoire : sans assurance ni visite technique valides, le véhicule ne peut pas être loué.',
              style: pw.TextStyle(fontSize: 7.5, color: _muted),
            ),
          ),

          section('Activité'),
          pw.Row(
            children: [
              stat('Locations', '${d.stats.rentals}'),
              stat('Revenu généré', formatMoneyShort(d.stats.revenue)),
              stat('Entretiens', '${d.stats.maintenances}'),
              stat('Incidents', '${d.stats.incidents}'),
            ],
          ),

          // Each heading is kept on the same page as its table.
          if (d.rentals.isNotEmpty)
            pw.Inseparable(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  section('Dernières locations'),
                  pw.TableHelper.fromTextArray(
                    headers: ['Locataire', 'Période', 'Statut', 'Montant'],
                    headerStyle: pw.TextStyle(
                      font: bold,
                      fontSize: 9,
                      color: PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(color: _navy),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellPadding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    oddRowDecoration: pw.BoxDecoration(color: _soft),
                    border: null,
                    cellAlignments: {3: pw.Alignment.centerRight},
                    data: [
                      for (final r in d.rentals)
                        [
                          r.clientName,
                          'du ${formatDate(r.rental.startDate)} au ${formatDate(r.rental.endDate)}',
                          r.rental.status.label,
                          formatMoney(r.rental.totalPrice),
                        ],
                    ],
                  ),
                ],
              ),
            ),

          if (d.maintenances.isNotEmpty)
            pw.Inseparable(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  section('Derniers entretiens'),
                  pw.TableHelper.fromTextArray(
                    headers: ['Intervention', 'Date', 'Statut', 'Observations'],
                    headerStyle: pw.TextStyle(
                      font: bold,
                      fontSize: 9,
                      color: PdfColors.white,
                    ),
                    headerDecoration: pw.BoxDecoration(color: _navy),
                    cellStyle: const pw.TextStyle(fontSize: 9),
                    cellPadding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 5,
                    ),
                    oddRowDecoration: pw.BoxDecoration(color: _soft),
                    border: null,
                    data: [
                      for (final m in d.maintenances)
                        [
                          m.type,
                          formatDate(m.date),
                          m.status.label,
                          m.description ?? '',
                        ],
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    return doc.save();
  }
}
