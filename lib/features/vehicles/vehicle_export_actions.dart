import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

import '../../app/theme.dart';
import '../../core/services/image_storage.dart';
import '../../core/services/vehicle_export_service.dart';
import '../../core/utils/ui_helpers.dart';
import '../../core/widgets/shared_widgets.dart';
import '../../repositories/maintenance_repository.dart';
import '../../repositories/rental_repository.dart';
import '../../repositories/vehicle_document_repository.dart';
import '../../repositories/vehicle_repository.dart';

/// Generates the PDF sheet of a vehicle, saves it and offers to open/share it.
Future<void> exportVehicleSheet(BuildContext context, int vehicleId) async {
  showSnack(context, 'Génération de la fiche PDF…');
  try {
    final repo = VehicleRepository();
    final v = await repo.getById(vehicleId);
    if (v == null) return;
    Uint8List? photo;
    if (v.photos.isNotEmpty) {
      try {
        final f = ImageStorage.fileFor(v.photos.first);
        if (await f.exists()) photo = await f.readAsBytes();
      } catch (_) {} // the sheet without photo rather than no sheet
    }
    final bytes = await VehicleExportService.buildVehicleSheet(VehicleSheetData(
      vehicle: v,
      availability: (await repo.getAvailabilityState(vehicleId)).label,
      stats: await repo.getStats(vehicleId),
      documents: await VehicleDocumentRepository().getByVehicle(vehicleId),
      rentals: (await RentalRepository().getViewsByVehicle(vehicleId))
          .take(5)
          .toList(),
      maintenances: (await MaintenanceRepository().getByVehicle(vehicleId))
          .take(5)
          .toList(),
      photo: photo,
      generatedAt: DateTime.now(),
    ));
    final file = await _save(
        bytes, 'AutoRent_fiche_${_slug('${v.brand}_${v.model}_${v.plate}')}', 'pdf');
    if (!context.mounted) return;
    await _showResult(context,
        file: file,
        title: 'Fiche PDF enregistrée',
        icon: Icons.picture_as_pdf_rounded,
        shareAsPdf: bytes);
  } catch (e) {
    if (context.mounted) {
      showSnack(context, 'Impossible de générer la fiche : $e',
          kind: SnackKind.error);
    }
  }
}

/// Exports the whole fleet (archived vehicles included) as a CSV file.
Future<void> exportFleetCsv(BuildContext context) async {
  try {
    final repo = VehicleRepository();
    final docs = await VehicleDocumentRepository().all();
    final rows = <FleetCsvRow>[];
    for (final v in await repo.getAll()) {
      final stats = await repo.getStats(v.id!);
      rows.add(FleetCsvRow(
        vehicle: v,
        availability: (await repo.getAvailabilityState(v.id!)).label,
        documents: docs[v.id] ?? const {},
        rentals: stats.rentals,
        revenue: stats.revenue,
      ));
    }
    final csv = VehicleExportService.buildFleetCsv(rows);
    final file =
        await _save(VehicleExportService.csvBytes(csv), 'AutoRent_flotte', 'csv');
    if (!context.mounted) return;
    await _showResult(context,
        file: file,
        title: 'Export CSV enregistré (${rows.length} véhicules)',
        icon: Icons.table_view_rounded);
  } catch (e) {
    if (context.mounted) {
      showSnack(context, "Impossible d'exporter la flotte : $e",
          kind: SnackKind.error);
    }
  }
}

// ── Saving & result dialog (same approach as the user report export) ───────

Future<Directory> _targetDir() async {
  try {
    final d = await getDownloadsDirectory(); // desktop: Téléchargements
    if (d != null) return d;
  } catch (_) {}
  try {
    final d = await getExternalStorageDirectory(); // Android: app folder
    if (d != null) return d;
  } catch (_) {}
  return getApplicationDocumentsDirectory();
}

String _slug(String s) => s
    .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
    .replaceAll(RegExp(r'^_+|_+$'), '');

Future<File> _save(Uint8List bytes, String baseName, String ext) async {
  final dir = await _targetDir();
  if (!await dir.exists()) await dir.create(recursive: true);
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  return File(p.join(dir.path, '${baseName}_$stamp.$ext'))
      .writeAsBytes(bytes, flush: true);
}

bool get _isDesktop => Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// Opens [path] with the default application (Excel, PDF viewer…).
Future<bool> _open(String path) async {
  try {
    if (Platform.isWindows) {
      return (await Process.run('cmd', ['/c', 'start', '', path])).exitCode == 0;
    }
    if (Platform.isMacOS) return (await Process.run('open', [path])).exitCode == 0;
    if (Platform.isLinux) {
      return (await Process.run('xdg-open', [path])).exitCode == 0;
    }
  } catch (_) {}
  return false;
}

Future<void> _showResult(
  BuildContext context, {
  required File file,
  required String title,
  required IconData icon,
  Uint8List? shareAsPdf,
}) =>
    showDialog<void>(
      context: context,
      builder: (dialogCtx) {
        String? status;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            icon: IconBadge(icon: icon, color: AppColors.success, size: 56),
            title: Text(title, textAlign: TextAlign.center),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Le fichier a été enregistré ici :'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: ctx.palette.surfaceAlt,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: SelectableText(file.path,
                      style: ctx.text.bodySmall
                          ?.copyWith(fontFamily: 'monospace')),
                ),
                if (status != null) ...[
                  const SizedBox(height: 8),
                  Text(status!,
                      style: ctx.text.bodySmall
                          ?.copyWith(color: AppColors.brand)),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: file.path));
                  setState(() => status = 'Chemin copié.');
                },
                child: const Text('Copier le chemin'),
              ),
              if (shareAsPdf != null && !_isDesktop)
                TextButton(
                  onPressed: () => Printing.sharePdf(
                      bytes: shareAsPdf, filename: p.basename(file.path)),
                  child: const Text('Partager'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Fermer'),
              ),
              if (_isDesktop)
                FilledButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: const Text('Ouvrir'),
                  onPressed: () async {
                    if (!await _open(file.path)) {
                      setState(() =>
                          status = "Impossible d'ouvrir le fichier automatiquement.");
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
