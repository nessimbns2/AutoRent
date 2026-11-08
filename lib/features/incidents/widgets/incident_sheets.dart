import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../models/enums.dart';
import '../../../models/incident.dart';
import '../../../models/vehicle.dart';
import 'incident_ui.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/// "Aujourd'hui", "Hier", "Il y a 3 j" (up to a week), otherwise dd/MM/yyyy.
String relativeDate(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return "Aujourd'hui";
  if (diff == 1) return 'Hier';
  if (diff > 1 && diff < 7) return 'Il y a $diff j';
  return formatDate(d);
}

/// Rounded modal bottom sheet with a drag handle, used by every sheet below.
Future<T?> _showSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool scrollControlled = false,
}) => showModalBottomSheet<T>(
  context: context,
  isScrollControlled: scrollControlled,
  showDragHandle: true,
  useSafeArea: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: builder,
);

// ─────────────────────────────────────────────────────────────────────────────
// Confirmation sheet (delete, discard changes, …)
// ─────────────────────────────────────────────────────────────────────────────
Future<bool> showIncidentConfirmSheet(
  BuildContext context, {
  required IconData icon,
  required Color color,
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Annuler',
}) async {
  final ok = await _showSheet<bool>(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1),
            duration: const Duration(milliseconds: 450),
            curve: Curves.elasticOut,
            builder: (_, s, child) => Transform.scale(scale: s, child: child),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 38, color: color),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: Theme.of(ctx).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: color,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return ok == true;
}

Future<bool> confirmDeleteIncident(
  BuildContext context,
  Incident inc,
) => showIncidentConfirmSheet(
  context,
  icon: Icons.delete_outline_rounded,
  color: IncidentPalette.danger,
  title: 'Supprimer ${inc.type.label.toLowerCase()} #${inc.id} ?',
  message: inc.photos.isEmpty
      ? 'Cette déclaration sera définitivement supprimée.'
      : 'Cette déclaration et ses ${inc.photos.length} photo(s) seront définitivement supprimées.',
  confirmLabel: 'Supprimer',
);

// ─────────────────────────────────────────────────────────────────────────────
// Status picker
// ─────────────────────────────────────────────────────────────────────────────
Future<IncidentStatus?> showStatusPickerSheet(
  BuildContext context,
  IncidentStatus current,
) => _showSheet<IncidentStatus>(
  context,
  builder: (ctx) {
    final scheme = Theme.of(ctx).colorScheme;
    const descriptions = {
      IncidentStatus.enAttente: 'Déclaré, pas encore pris en charge',
      IncidentStatus.enCours: 'Prise en charge en cours (dépannage, garage…)',
      IncidentStatus.resolu: 'Problème réglé, dossier clôturé',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 8, 12),
            child: Text(
              'Changer le statut',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
          ),
          for (final (i, s) in IncidentStatus.values.indexed)
            EntranceAnimation(
              delay: EntranceAnimation.staggerDelay(i),
              offsetY: 12,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: s == current
                      ? s.color.withValues(alpha: 0.12)
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => Navigator.pop(ctx, s),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: s == current ? s.color : scheme.outlineVariant,
                          width: s == current ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: s.color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
                            child: Icon(s.icon, size: 22, color: s.color),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.label,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  descriptions[s]!,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (s == current)
                            Icon(Icons.check_circle_rounded, color: s.color),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Quick actions (long-press on a card)
// ─────────────────────────────────────────────────────────────────────────────
enum IncidentAction { open, edit, changeStatus, delete }

Future<IncidentAction?> showIncidentActionsSheet(
  BuildContext context,
  IncidentView view,
) => _showSheet<IncidentAction>(
  context,
  builder: (ctx) {
    final inc = view.incident;
    final scheme = Theme.of(ctx).colorScheme;
    Widget action(
      IncidentAction a,
      IconData icon,
      String label, {
      Color? color,
      String? subtitle,
    }) => ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: (color ?? IncidentPalette.brown).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: color ?? IncidentPalette.brown),
      ),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      onTap: () => Navigator.pop(ctx, a),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: [
              IncidentTypeBadge(type: inc.type, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${inc.type.label} #${inc.id}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      view.vehicleLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IncidentStatusPill(status: inc.status),
            ],
          ),
        ),
        const Divider(height: 1),
        action(IncidentAction.open, Icons.visibility_rounded, 'Voir le détail'),
        action(IncidentAction.edit, Icons.edit_rounded, 'Modifier'),
        action(
          IncidentAction.changeStatus,
          Icons.swap_horiz_rounded,
          'Changer le statut',
          subtitle: 'Actuellement : ${inc.status.label}',
        ),
        action(
          IncidentAction.delete,
          Icons.delete_outline_rounded,
          'Supprimer',
          color: IncidentPalette.danger,
        ),
        const SizedBox(height: 12),
      ],
    );
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// Vehicle picker with search
// ─────────────────────────────────────────────────────────────────────────────
Future<Vehicle?> showVehiclePickerSheet(
  BuildContext context, {
  required List<Vehicle> vehicles,
  int? selectedId,
}) => _showSheet<Vehicle>(
  context,
  scrollControlled: true,
  builder: (ctx) => _VehiclePicker(vehicles: vehicles, selectedId: selectedId),
);

class _VehiclePicker extends StatefulWidget {
  final List<Vehicle> vehicles;
  final int? selectedId;
  const _VehiclePicker({required this.vehicles, this.selectedId});

  @override
  State<_VehiclePicker> createState() => _VehiclePickerState();
}

class _VehiclePickerState extends State<_VehiclePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final q = _q.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.vehicles
        : widget.vehicles
              .where((v) => v.label.toLowerCase().contains(q))
              .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, controller) => Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choisir le véhicule',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Marque, modèle ou immatriculation',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(
                      'Aucun véhicule trouvé',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final v = list[i];
                      final selected = v.id == widget.selectedId;
                      return EntranceAnimation(
                        delay: EntranceAnimation.staggerDelay(i),
                        offsetY: 12,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: selected
                                ? scheme.primaryContainer.withValues(alpha: 0.5)
                                : scheme.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(18),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.pop(context, v),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CarImage(
                                        fileName: v.photos.isNotEmpty
                                            ? v.photos.first
                                            : null,
                                        width: 76,
                                        height: 56,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${v.brand} ${v.model}',
                                            style: const TextStyle(
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: scheme.outline,
                                              ),
                                            ),
                                            child: Text(
                                              v.plate,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: scheme.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success popup (auto-closes)
// ─────────────────────────────────────────────────────────────────────────────
Future<void> showIncidentSuccessDialog(
  BuildContext context, {
  required String title,
  required String message,
  required Color color,
}) {
  final nav = Navigator.of(context);
  var closed = false;
  Future.delayed(const Duration(milliseconds: 1500), () {
    if (!closed && nav.mounted) nav.pop();
  });
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'success',
    barrierColor: Colors.black38,
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (ctx, a, _, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: a, child: child),
    ),
    pageBuilder: (ctx, _, _) => Center(
      child: Material(
        color: Theme.of(ctx).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 52,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(() => closed = true);
}
