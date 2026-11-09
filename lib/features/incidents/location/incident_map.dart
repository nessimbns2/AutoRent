import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';


/// Tunis, used when no position is known yet.
const tunisCenter = LatLng(36.8065, 10.1815);

/// OpenStreetMap tiles shared by every map of the module.
TileLayer osmTileLayer() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.example.projetmobile1',
  maxZoom: 19,
);

/// Required OpenStreetMap credit.
Widget osmAttribution() =>
    const SimpleAttributionWidget(source: Text('OpenStreetMap contributors'));

/// Brown map pin.
class IncidentPin extends StatelessWidget {
  final double size;
  final Color color;
  const IncidentPin({
    super.key,
    this.size = 46,
    this.color = AppColors.brand,
  });

  @override
  Widget build(BuildContext context) => Icon(
    Icons.location_on_rounded,
    size: size,
    color: color,
    shadows: const [
      Shadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3)),
    ],
  );
}

/// Small non-interactive map with a pin, used in the form and the detail.
class IncidentMapPreview extends StatelessWidget {
  final LatLng point;
  final double height;
  final Color pinColor;
  final VoidCallback? onTap;

  const IncidentMapPreview({
    super.key,
    required this.point,
    this.height = 170,
    this.pinColor = AppColors.brand,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            FlutterMap(
              // Rebuild the map when the point changes.
              key: ValueKey('${point.latitude},${point.longitude}'),
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                osmTileLayer(),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 46,
                      height: 46,
                      alignment: Alignment.topCenter,
                      child: IncidentPin(color: pinColor),
                    ),
                  ],
                ),
              ],
            ),
            if (onTap != null)
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(onTap: onTap),
                ),
              ),
            if (onTap != null)
              Positioned(
                right: 10,
                bottom: 10,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_full_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Agrandir',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Formats a position as "36.80650, 10.18150".
String formatLatLng(LatLng p) =>
    '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}';
