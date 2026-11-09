import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/user_activity.dart';
import '../../models/user_report.dart';

/// Builds the "Rapport utilisateur" PDF. Pure Dart (no network, no native
/// code). Text is kept to Latin-1 characters because the built-in PDF fonts
/// do not cover curly quotes, dashes or bullets.
class UserReportService {
  UserReportService._();

  static const _brand = PdfColor.fromInt(0xFFE65100);
  static const _ink = PdfColor.fromInt(0xFF212121);
  static const _muted = PdfColor.fromInt(0xFF757575);
  static const _line = PdfColor.fromInt(0xFFE0E0E0);
  static const _tint = PdfColor.fromInt(0xFFFFF3E0);
  static const _ok = PdfColor.fromInt(0xFF2E7D32);
  static const _bad = PdfColor.fromInt(0xFFC62828);

  /// Max rows shown in the activity table.
  static const maxActivityRows = 25;

  static Future<Uint8List> build(UserReportData data) async {
    try {
      return await _render(data);
    } catch (_) {
      // Most likely an avatar the PDF library cannot decode: retry without it.
      if (data.avatar == null) rethrow;
      return _render(data.withoutAvatar());
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String date(DateTime d) =>
      '${_two(d.day)}/${_two(d.month)}/${d.year}';

  static String dateTime(DateTime d) =>
      '${date(d)} ${_two(d.hour)}:${_two(d.minute)}';

  /// 1234.5 -> "1,234.500 DT" (same style as the app).
  static String money(double v) {
    final fixed = v.toStringAsFixed(3);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      final fromEnd = intPart.length - i;
      buf.write(intPart[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1 && intPart[i] != '-') buf.write(',');
    }
    return '$buf.${parts[1]} DT';
  }

  /// Counts used by the "30 derniers jours" boxes.
  static ({int logins, int failures, int passwordChanges, DateTime? lastLogin})
      recentStats(List<UserActivity> activity, DateTime now) {
    final since = now.subtract(const Duration(days: 30));
    var logins = 0, failures = 0, changes = 0;
    DateTime? lastLogin;
    for (final a in activity) {
      if (a.action == ActivityAction.login && lastLogin == null) {
        lastLogin = a.createdAt;
      }
      if (a.createdAt.isBefore(since)) continue;
      switch (a.action) {
        case ActivityAction.login:
          logins++;
        case ActivityAction.loginFailed:
        case ActivityAction.recoveryFailed:
        case ActivityAction.totpFailed:
          failures++;
        case ActivityAction.passwordChanged:
        case ActivityAction.passwordResetRecovery:
        case ActivityAction.passwordResetColleague:
          changes++;
      }
    }
    return (
      logins: logins,
      failures: failures,
      passwordChanges: changes,
      lastLogin: lastLogin
    );
  }

  // ── Document ──────────────────────────────────────────────────────────────

  static Future<Uint8List> _render(UserReportData d) async {
    final user = d.user;
    final doc = pw.Document(
      title: 'Rapport utilisateur - ${user.fullName}',
      author: 'AutoRent',
      creator: 'AutoRent',
    );
    final stats = recentStats(d.activity, d.generatedAt);
    final locked = user.lockedUntil != null &&
        user.lockedUntil!.isAfter(d.generatedAt);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 44),
        header: (ctx) => ctx.pageNumber == 1 ? pw.SizedBox() : _runningHeader(user.fullName),
        footer: (ctx) => _footer(ctx, d),
        build: (ctx) => [
          _banner(),
          pw.SizedBox(height: 18),
          _profile(d),
          pw.SizedBox(height: 18),
          _sectionTitle('Sécurité du compte'),
          _keyValueTable([
            ['Double authentification (2FA)', user.totpEnabled ? 'Activée' : 'Désactivée'],
            ['Clé de récupération', user.recoveryKeyHash != null ? 'Définie' : 'Non définie'],
            [
              'État du compte',
              locked ? 'Verrouillé jusqu\'à ${dateTime(user.lockedUntil!)}' : 'Actif',
            ],
            ['Tentatives échouées en cours', '${user.failedAttempts}'],
          ], goodRows: {
            0: user.totpEnabled,
            1: user.recoveryKeyHash != null,
            2: !locked,
          }),
          pw.SizedBox(height: 18),
          _sectionTitle('Activité des 30 derniers jours'),
          pw.Row(children: [
            _statBox('Connexions', '${stats.logins}'),
            _gap(),
            _statBox('Échecs de connexion', '${stats.failures}',
                color: stats.failures > 0 ? _bad : _ink),
            _gap(),
            _statBox('Mots de passe changés', '${stats.passwordChanges}'),
            _gap(),
            _statBox('Dernière connexion',
                stats.lastLogin == null ? '-' : dateTime(stats.lastLogin!),
                small: true),
          ]),
          pw.SizedBox(height: 18),
          _sectionTitle('Activité commerciale'),
          pw.Row(children: [
            _statBox('Contrats créés', '${d.business.rentals}'),
            _gap(),
            _statBox('En cours', '${d.business.active}'),
            _gap(),
            _statBox('Terminés', '${d.business.completed}'),
            _gap(),
            _statBox('Incidents déclarés', '${d.business.incidents}'),
          ]),
          pw.SizedBox(height: 8),
          _statBox('Chiffre d\'affaires généré (hors annulations)',
              money(d.business.revenue),
              wide: true),
          pw.SizedBox(height: 18),
          _sectionTitle(
              'Journal d\'activité (${d.activity.length > maxActivityRows ? '$maxActivityRows derniers événements' : '${d.activity.length} événement${d.activity.length > 1 ? 's' : ''}'})'),
          _activityTable(d.activity.take(maxActivityRows).toList()),
        ],
      ),
    );
    return doc.save();
  }

  // ── Pieces ────────────────────────────────────────────────────────────────

  static pw.Widget _banner() => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: pw.BoxDecoration(
          color: _brand,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('AutoRent',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold)),
                pw.Text('Gestion de location de voitures',
                    style: const pw.TextStyle(
                        color: PdfColors.white, fontSize: 10)),
              ],
            ),
            pw.Text('Rapport utilisateur',
                style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold)),
          ],
        ),
      );

  static pw.Widget _runningHeader(String name) => pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 10),
        padding: const pw.EdgeInsets.only(bottom: 4),
        decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _line))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('AutoRent - Rapport utilisateur',
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
            pw.Text(name, style: const pw.TextStyle(fontSize: 9, color: _muted)),
          ],
        ),
      );

  static pw.Widget _footer(pw.Context ctx, UserReportData d) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _line))),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Text(
                'Généré le ${dateTime(d.generatedAt)}'
                '${d.generatedBy == null ? '' : ' par ${d.generatedBy!.fullName}'}'
                '. Document confidentiel : il ne contient ni mot de passe, '
                'ni clé de récupération, ni secret 2FA.',
                style: const pw.TextStyle(fontSize: 8, color: _muted),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: _muted)),
          ],
        ),
      );

  static pw.Widget _profile(UserReportData d) {
    final u = d.user;
    final pw.Widget avatar = d.avatar != null
        ? pw.ClipOval(
            child: pw.Image(pw.MemoryImage(d.avatar!),
                width: 64, height: 64, fit: pw.BoxFit.cover))
        : pw.Container(
            width: 64,
            height: 64,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(
                color: _tint, shape: pw.BoxShape.circle),
            child: pw.Text(u.initials,
                style: pw.TextStyle(
                    color: _brand,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold)),
          );
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        avatar,
        pw.SizedBox(width: 16),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(u.fullName,
                  style: pw.TextStyle(
                      fontSize: 18,
                      color: _ink,
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 3),
              pw.Text(u.email,
                  style: const pw.TextStyle(fontSize: 11, color: _muted)),
              pw.SizedBox(height: 3),
              pw.Text(
                  'Compte créé le ${date(u.createdAt)}  |  Identifiant n° ${u.id ?? '-'}',
                  style: const pw.TextStyle(fontSize: 10, color: _muted)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _sectionTitle(String text) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(bottom: 8),
        padding: const pw.EdgeInsets.only(bottom: 3),
        decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _brand, width: 1.2))),
        child: pw.Text(text,
            style: pw.TextStyle(
                fontSize: 12, color: _brand, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _gap() => pw.SizedBox(width: 8);

  static pw.Widget _statBox(String label, String value,
      {PdfColor color = _ink, bool small = false, bool wide = false}) {
    final box = pw.Container(
      width: wide ? double.infinity : null,
      height: wide ? null : 54,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: _tint,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: small ? 10 : 18,
                  color: color,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _muted)),
        ],
      ),
    );
    return wide ? box : pw.Expanded(child: box);
  }

  static pw.Widget _keyValueTable(List<List<String>> rows,
      {Map<int, bool> goodRows = const {}}) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(2),
      },
      border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
      children: [
        for (var i = 0; i < rows.length; i++)
          pw.TableRow(children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Text(rows[i][0],
                  style: const pw.TextStyle(fontSize: 10, color: _muted)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              child: pw.Text(rows[i][1],
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: goodRows[i] == null
                          ? _ink
                          : (goodRows[i]! ? _ok : _bad))),
            ),
          ]),
      ],
    );
  }

  static pw.Widget _activityTable(List<UserActivity> items) {
    if (items.isEmpty) {
      return pw.Text('Aucune activité enregistrée.',
          style: const pw.TextStyle(fontSize: 10, color: _muted));
    }
    pw.Widget cell(String t, {bool head = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: pw.Text(t,
              style: pw.TextStyle(
                  fontSize: head ? 9 : 9,
                  color: head ? PdfColors.white : _ink,
                  fontWeight: head ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );
    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(88),
        1: const pw.FlexColumnWidth(3),
        2: const pw.FlexColumnWidth(2),
      },
      border: const pw.TableBorder(
          horizontalInside: pw.BorderSide(color: _line, width: 0.5)),
      children: [
        pw.TableRow(
          repeat: true, // header is repeated on every page
          decoration: const pw.BoxDecoration(color: _brand),
          children: [cell('Date', head: true), cell('Événement', head: true), cell('Détail', head: true)],
        ),
        for (final a in items)
          pw.TableRow(children: [
            cell(dateTime(a.createdAt)),
            cell(_plain(a.label)),
            cell(_plain(a.detail ?? '')),
          ]),
      ],
    );
  }

  /// Map the few non-Latin-1 characters that can appear in labels to ASCII.
  static String _plain(String s) => s
      .replaceAll('\u2019', "'")
      .replaceAll('\u2013', '-')
      .replaceAll('\u2014', '-')
      .replaceAll('\u00AB', '"')
      .replaceAll('\u00BB', '"');
}
