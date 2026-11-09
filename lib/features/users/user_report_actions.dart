import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/services/image_storage.dart';
import '../../core/services/user_report_service.dart';
import '../../core/session/session_manager.dart';
import '../../core/utils/ui_helpers.dart';
import '../../models/user.dart';
import '../../models/user_activity.dart';
import '../../models/user_report.dart';
import '../../repositories/user_repository.dart';

/// Generates the PDF report of [user], saves it on the device, then offers to
/// open it. Works fully offline. Safe to call from any screen.
Future<void> exportUserReport(BuildContext context, User user) async {
  if (user.id == null) return;
  final repo = UserRepository();
  final actor = SessionManager.instance.currentUser;
  showSnack(context, 'Génération du rapport...');
  try {
    final activity = await repo.getActivity(user.id!, limit: 500);
    final business = await repo.getBusinessStats(user.id!);

    Uint8List? avatar;
    final photo = user.photoFile;
    if (photo != null) {
      try {
        final f = ImageStorage.fileFor(photo);
        if (await f.exists()) avatar = await f.readAsBytes();
      } catch (_) {} // no photo in the report rather than no report
    }

    final bytes = await UserReportService.build(UserReportData(
      user: user,
      generatedBy: actor,
      generatedAt: DateTime.now(),
      activity: activity,
      avatar: avatar,
      business: business,
    ));
    final file = await _save(bytes, user);

    await repo.logActivity(user.id!, ActivityAction.reportExported,
        detail: actor == null ? null : 'Par ${actor.fullName}');
    if (!context.mounted) return;
    await _showResult(context, file);
  } catch (e) {
    if (context.mounted) {
      showSnack(context, 'Impossible de générer le rapport : $e');
    }
  }
}

Future<Directory> _targetDir() async {
  try {
    final d = await getDownloadsDirectory(); // desktop
    if (d != null) return d;
  } catch (_) {}
  try {
    final d = await getExternalStorageDirectory(); // Android (app folder)
    if (d != null) return d;
  } catch (_) {}
  return getApplicationDocumentsDirectory();
}

String _slug(String s) {
  final t = s.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  return t.replaceAll(RegExp(r'^_+|_+$'), '');
}

Future<File> _save(Uint8List bytes, User user) async {
  final dir = await _targetDir();
  if (!await dir.exists()) await dir.create(recursive: true);
  final now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  final stamp =
      '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  final name = _slug('${user.firstName}_${user.lastName}');
  final file = File(p.join(
      dir.path, 'AutoRent_rapport_${name.isEmpty ? 'utilisateur' : name}_$stamp.pdf'));
  return file.writeAsBytes(bytes, flush: true);
}

bool get _canOpenFiles =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// Opens [path] with the system's default PDF viewer (desktop only).
Future<bool> _open(String path) async {
  try {
    if (Platform.isWindows) {
      return (await Process.run('cmd', ['/c', 'start', '', path])).exitCode == 0;
    }
    if (Platform.isMacOS) {
      return (await Process.run('open', [path])).exitCode == 0;
    }
    if (Platform.isLinux) {
      return (await Process.run('xdg-open', [path])).exitCode == 0;
    }
  } catch (_) {}
  return false;
}

Future<void> _showResult(BuildContext context, File file) {
  return showDialog<void>(
    context: context,
    builder: (dialogCtx) {
      String? status;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Rapport PDF enregistré'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Le fichier a été enregistré ici :'),
              const SizedBox(height: 8),
              SelectableText(file.path,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              if (status != null) ...[
                const SizedBox(height: 8),
                Text(status!,
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(ctx).colorScheme.primary)),
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
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Fermer'),
            ),
            if (_canOpenFiles)
              FilledButton.icon(
                icon: const Icon(Icons.picture_as_pdf, size: 18),
                label: const Text('Ouvrir'),
                onPressed: () async {
                  final ok = await _open(file.path);
                  if (!ok) {
                    setState(() => status = "Impossible d'ouvrir le fichier automatiquement.");
                  }
                },
              ),
          ],
        ),
      );
    },
  );
}
