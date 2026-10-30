import 'package:latlong2/latlong.dart';

class RrydLocationPoint {
  const RrydLocationPoint({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;

  LatLng get latLng => LatLng(latitude, longitude);

  bool get isInsideNepal =>
      latitude >= 26 &&
      latitude <= 31 &&
      longitude >= 80 &&
      longitude <= 89;
}

class RrydRouteResult {
  const RrydRouteResult({
    required this.distanceKm,
    required this.durationMinutes,
    required this.points,
  });

  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> points;
}

class RrydPlaceSearchResult {
  const RrydPlaceSearchResult({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;

  RrydLocationPoint toPoint() => RrydLocationPoint(
        label: label,
        latitude: latitude,
        longitude: longitude,
      );
}
