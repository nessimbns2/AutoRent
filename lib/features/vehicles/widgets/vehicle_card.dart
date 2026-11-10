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
    final showDocs =
        documentAlert != null &&
        availability != VehicleAvailability.documentsExpires;
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
                  borderRadius: BorderRadius.circular(AppRadius.lg - 6),
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
                      // Soft vignette for depth and chip legibility.
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0x26000000),
                              Color(0x00000000),
                              Color(0x00000000),
                              Color(0x33000000),
                            ],
                            stops: [0, 0.3, 0.7, 1],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 8,
                        right: showDocs ? 40 : 8,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _GlassChip(
                            label: availability.label,
                            color: vehicleAvailabilityColor(availability),
                          ),
                        ),
                      ),
                      if (showDocs)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Tooltip(
                            message: documentAlert == DocumentStatus.expired
                                ? 'Un document est expiré'
                                : 'Un document expire bientôt',
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                gradient: AppColors.tint(
                                  documentStatusColor(documentAlert!),
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.priority_high_rounded,
                                size: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      if (vehicle.photos.length > 1)
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.photo_library_rounded,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${vehicle.photos.length}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicle.brand} ${vehicle.model}',
                    style: context.text.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    vehicle.plate,
                    style: context.text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (specs.isNotEmpty)
                    Text(
                      specs,
                      style: context.text.labelSmall?.copyWith(
                        color: context.palette.muted,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: vehicle.pricePerDay.toStringAsFixed(0),
                                style: context.text.titleLarge?.copyWith(
                                  fontSize: 20,
                                  letterSpacing: -0.6,
                                  color: context.isDark
                                      ? Colors.white
                                      : AppColors.ink,
                                ),
                              ),
                              TextSpan(
                                text: ' DT/jour',
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brand.withValues(alpha: 0.38),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Frosted availability pill over the vehicle photo.
class _GlassChip extends StatelessWidget {
  final String label;
  final Color color;
  const _GlassChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: context.isDark
          ? AppColors.ink.withValues(alpha: 0.72)
          : Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(30),
      boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.isDark ? Colors.white : AppColors.ink,
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
