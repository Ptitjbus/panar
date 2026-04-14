import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/gps_point_entity.dart';

class RunStaticMapWidget extends StatelessWidget {
  final List<GpsPointEntity> points;

  const RunStaticMapWidget({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latLngPoints = points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    if (latLngPoints.isEmpty) {
      return Container(
        height: 200,
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: Text('Aucun tracé disponible')),
      );
    }

    // Calculer les bounds pour centrer la carte sur le tracé
    double minLat = latLngPoints.first.latitude;
    double maxLat = latLngPoints.first.latitude;
    double minLng = latLngPoints.first.longitude;
    double maxLng = latLngPoints.first.longitude;
    for (final p in latLngPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final centerLat = (minLat + maxLat) / 2;
    final centerLng = (minLng + maxLng) / 2;

    return SizedBox(
      height: 250,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(centerLat, centerLng),
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.panar',
            ),
            if (latLngPoints.length >= 2)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: latLngPoints,
                    strokeWidth: 4,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: latLngPoints.first,
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
                Marker(
                  point: latLngPoints.last,
                  width: 20,
                  height: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
