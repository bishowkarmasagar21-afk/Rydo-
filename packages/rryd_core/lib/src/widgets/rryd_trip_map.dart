import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/rryd_location.dart';
import '../theme/rryd_theme.dart';

class RrydTripMap extends StatelessWidget {
  const RrydTripMap({
    super.key,
    this.pickup,
    this.destination,
    this.route = const [],
    this.driverLocation,
    this.passengerLocation,
    this.driverRoute = const [],
    this.applicationId = 'com.rryd.passenger',
    this.onMapTap,
    this.showCurrentMapPinHint = true,
  });

  final RrydLocationPoint? pickup;
  final RrydLocationPoint? destination;
  final List<LatLng> route;
  final RrydLocationPoint? driverLocation;
  final RrydLocationPoint? passengerLocation;
  final List<LatLng> driverRoute;
  final String applicationId;
  final ValueChanged<LatLng>? onMapTap;
  final bool showCurrentMapPinHint;

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];

    if (pickup != null) {
      markers.add(
        Marker(
          point: pickup!.latLng,
          width: 46,
          height: 54,
          child: const _MapPin(
            color: Color(0xFF16B981),
            icon: Icons.trip_origin_rounded,
          ),
        ),
      );
    }
    if (destination != null) {
      markers.add(
        Marker(
          point: destination!.latLng,
          width: 46,
          height: 54,
          child: const _MapPin(
            color: RrydTheme.orange,
            icon: Icons.location_on_rounded,
          ),
        ),
      );
    }
    if (driverLocation != null) {
      markers.add(
        Marker(
          point: driverLocation!.latLng,
          width: 46,
          height: 54,
          child: const _MapPin(
            color: Color(0xFF3B82F6),
            icon: Icons.directions_car_filled_rounded,
          ),
        ),
      );
    }
    if (passengerLocation != null) {
      markers.add(
        Marker(
          point: passengerLocation!.latLng,
          width: 46,
          height: 54,
          child: const _MapPin(
            color: Color(0xFF8B5CF6),
            icon: Icons.person_pin_circle_rounded,
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: pickup?.latLng ??
                  destination?.latLng ??
                  const LatLng(27.7172, 85.3240),
              initialZoom: 13,
              minZoom: 5,
              maxZoom: 18,
              onTap: onMapTap == null
                  ? null
                  : (tapPosition, point) => onMapTap!(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: applicationId,
                maxZoom: 19,
              ),
              if (route.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route,
                      strokeWidth: 5,
                      color: RrydTheme.orange,
                    ),
                  ],
                ),
              if (driverRoute.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: driverRoute,
                      strokeWidth: 4,
                      color: const Color(0xFF3B82F6),
                      pattern: StrokePattern.dotted(),
                    ),
                  ],
                ),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),
          if (showCurrentMapPinHint && onMapTap != null)
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: IgnorePointer(
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF08111B).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      child: Text(
                        'Tap the map to place the selected pin',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: color, size: 40, shadows: const [
      Shadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
    ]);
  }
}
