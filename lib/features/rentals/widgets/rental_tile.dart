import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/widgets/status_chips.dart';
import '../../../models/enums.dart';
import '../../../models/rental.dart';

/// Splits "Marque Modèle · PLAQUE" into its two parts.
(String, String) splitVehicleLabel(String label) {
  final i = label.lastIndexOf(' · ');
  if (i < 0) return (label, '');
  return (label.substring(0, i), label.substring(i + 3));
}

/// Card summarising a rental contract — used in lists and on the dashboard.
class RentalTile extends StatelessWidget {
  final RentalView view;
  final VoidCallback? onTap;
  final bool showClient;
  final EdgeInsetsGeometry margin;

  const RentalTile({
    super.key,
    required this.view,
    this.onTap,
    this.showClient = true,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    final r = view.rental;
    final overdue = isRentalOverdue(r);
    final color = overdue ? AppColors.danger : rentalStatusColor(r.status);
    final (name, plate) = splitVehicleLabel(view.vehicleLabel);

    double? progress;
    if (r.status == RentalStatus.enCours) {
      final total = r.endDate.difference(r.startDate).inHours;
      final done = DateTime.now().difference(r.startDate).inHours;
      progress = total <= 0 ? 1 : (done / total).clamp(0.0, 1.0);
    }

    return AppCard(
      margin: margin,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            IconBadge(
                icon: overdue
                    ? Icons.schedule_rounded
                    : rentalStatusIcon(r.status),
                color: color,
                size: 46),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: context.text.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    showClient
                        ? '${view.clientName}${plate.isNotEmpty ? ' · $plate' : ''}'
                        : plate,
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatMoneyShort(r.totalPrice),
                    style: context.text.titleSmall
                        ?.copyWith(color: AppColors.brand)),
                const SizedBox(height: 4),
                rentalStatusChip(r.status, overdue: overdue),
              ],
            ),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: context.palette.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
            ),
            child: Row(children: [
              Icon(Icons.calendar_month_rounded,
                  size: 16, color: context.palette.muted),
              const SizedBox(width: 8),
              Text(formatDayMonth(r.startDate), style: context.text.labelMedium),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward_rounded,
                    size: 15, color: context.palette.muted),
              ),
              Expanded(
                child: Text(formatDayMonth(r.endDate),
                    style: context.text.labelMedium),
              ),
              Text('${r.days} j',
                  style: context.text.labelMedium
                      ?.copyWith(color: context.palette.muted)),
            ]),
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: overdue ? AppColors.danger : AppColors.info,
                backgroundColor: context.palette.surfaceAlt,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
