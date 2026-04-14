import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/gps_point_entity.dart';
import '../../../../shared/widgets/animated_avatar_widget.dart';

class RunMapWidget extends StatelessWidget {
  final List<GpsPointEntity> points;
  final MapController mapController;

  const RunMapWidget({
    super.key,
    required this.points,
    required this.mapController,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latLngPoints = points
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();
    final center = latLngPoints.isNotEmpty
        ? latLngPoints.last
        : const LatLng(48.8566, 2.3522); // Paris par défaut

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(initialCenter: center, initialZoom: 16),
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
        if (latLngPoints.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: latLngPoints.last,
                width: 40,
                height: 40,
                child: const AnimatedAvatarWidget(
                  isMoving: true, // Always walking during a run
                  size: 40,
                  showShadow: true,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
