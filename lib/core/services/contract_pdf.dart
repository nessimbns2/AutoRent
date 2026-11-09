import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../models/rental.dart';
import '../utils/formatters.dart';

/// Builds the rental contract and opens the system share sheet
/// (WhatsApp, email, save...).
Future<void> shareContractPdf(RentalView v) async {
  final r = v.rental;
  final font =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Regular.ttf'));
  final bold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
  final doc = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: bold));

  pw.Widget row(String k, String val, {bool strong = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 4),
        child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(k),
              pw.Text(val,
                  style: strong ? pw.TextStyle(font: bold, fontSize: 14) : null),
            ]),
      );

  doc.addPage(pw.Page(
    build: (_) =>
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text('AutoRent', style: pw.TextStyle(font: bold, fontSize: 24)),
      pw.Text('Contrat de location n° ${r.id}'),
      pw.Divider(height: 28),
      row('Locataire', v.clientName),
      row('Véhicule', v.vehicleLabel),
      row('Départ', formatDate(r.startDate)),
      row('Retour', formatDate(r.endDate)),
      row('Durée', '${r.days} jour(s)'),
      row('Tarif journalier', formatMoney(r.totalPrice / r.days)),
      row('Statut', r.status.label),
      pw.Divider(height: 28),
      row('Montant total', formatMoney(r.totalPrice), strong: true),
      pw.SizedBox(height: 48),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('Signature du locataire'),
        pw.Text("Signature de l'agence"),
      ]),
    ]),
  ));

  await Printing.sharePdf(
      bytes: await doc.save(), filename: 'contrat-${r.id}.pdf');
}
