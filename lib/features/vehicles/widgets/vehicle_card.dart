import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/shared_widgets.dart';
import '../../../core/widgets/status_chips.dart';
import '../../../models/enums.dart';
import '../../../models/vehicle.dart';
import '../../../models/vehicle_document.dart';

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VehicleAvailability availability;

  /// Worst document status of the vehicle (expired / expiring soon) or null.
  final DocumentStatus? documentAlert;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.availability,
    required this.onTap,
    this.documentAlert,
    this.onLongPress,
  });

  /// "SUV · Hybride · Auto · 5 pl." from the technical sheet.
  static String specsLine(Vehicle v) => [
        v.category?.label,
        v.fuel?.label,
        if (v.gearbox != null)
          v.gearbox == Gearbox.automatique ? 'Auto' : 'Manuelle',
        if (v.seats != null) '${v.seats} pl.',
      ].whereType<String>().join(' · ');

  @override
  Widget build(BuildContext context) {
    final specs = specsLine(vehicle);
    return Opacity(
      opacity: vehicle.archived ? 0.7 : 1,
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg - 4),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Hero(
                        tag: 'vehicle-${vehicle.id}',
                        child: CarImage(
                          fileName: vehicle.photos.isNotEmpty
                              ? vehicle.photos.first
                              : null,
                          seed: vehicle.id ?? 0,
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child:
                            vehicleAvailabilityChip(availability, solid: true),
                      ),
                      if (documentAlert != null &&
                          availability != VehicleAvailability.documentsExpires)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Tooltip(
                            message: documentAlert == DocumentStatus.expired
                                ? 'Un document est expiré'
                                : 'Un document expire bientôt',
                            child: StatusChip(
                              label: 'Docs',
                              icon: Icons.warning_amber_rounded,
                              color: documentStatusColor(documentAlert!),
                              solid: true,
                            ),
                          ),
                        ),
                      if (vehicle.photos.length > 1)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.photo_library_rounded,
                                  size: 12, color: Colors.white),
                              const SizedBox(width: 4),
                              Text('${vehicle.photos.length}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 11)),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle.brand} ${vehicle.model}',
                    style: context.text.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(vehicle.plate,
                      style: context.text.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (specs.isNotEmpty)
                    Text(specs,
                        style: context.text.labelSmall
                            ?.copyWith(color: context.palette.muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: vehicle.pricePerDay.toStringAsFixed(0),
                            style: context.text.titleMedium
                                ?.copyWith(color: AppColors.brand),
                          ),
                          TextSpan(
                            text: ' DT/jour',
                            style: context.text.bodySmall,
                          ),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color:
                            context.isDark ? AppColors.brand : AppColors.ink,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
