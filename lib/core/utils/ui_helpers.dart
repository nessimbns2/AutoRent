import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../widgets/shared_widgets.dart';

enum SnackKind { info, success, error }

void showSnack(BuildContext context, String message,
    {SnackKind kind = SnackKind.info}) {
  final lower = message.toLowerCase();
  // Auto-detect the kind from the French wording when not specified.
  final k = kind != SnackKind.info
      ? kind
      : (lower.contains('impossible') ||
              lower.contains('incorrect') ||
              lower.contains('erreur') ||
              lower.contains('veuillez') ||
              lower.contains('existe déjà') ||
              lower.contains('aucun'))
          ? SnackKind.error
          : (lower.contains('ajouté') ||
                  lower.contains('modifié') ||
                  lower.contains('supprimé') ||
                  lower.contains('créé') ||
                  lower.contains('mis à jour') ||
                  lower.contains('enregistré') ||
                  lower.contains('réinitialisé') ||
                  lower.contains('déclaré'))
              ? SnackKind.success
              : SnackKind.info;

  final (icon, color) = switch (k) {
    SnackKind.success => (Icons.check_circle_rounded, AppColors.success),
    SnackKind.error => (Icons.error_rounded, AppColors.danger),
    SnackKind.info => (Icons.info_rounded, AppColors.brand),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
    ));
}

Future<bool?> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirmer',
  bool? destructive,
  IconData? icon,
}) {
  final danger = destructive ??
      (confirmLabel.toLowerCase().contains('supprimer') ||
          title.toLowerCase().contains('annuler') ||
          title.toLowerCase().contains('déconnexion'));
  final color = danger ? AppColors.danger : AppColors.brand;

  return showDialog<bool>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      icon: IconBadge(
        icon: icon ??
            (danger ? Icons.warning_amber_rounded : Icons.help_outline_rounded),
        color: color,
        size: 56,
      ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(children: [
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Annuler'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: color, minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: Text(confirmLabel),
            ),
          ),
        ]),
      ],
    ),
  );
}
