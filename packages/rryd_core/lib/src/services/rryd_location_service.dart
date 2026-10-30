import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/rryd_location.dart';

/// Location tools for the first development version.
///
/// Nominatim and the public OSRM demo endpoint are development endpoints,
/// not a production SLA or an unlimited free service. Search is manual
/// (never autocomplete), cached in memory, and rate-limited to one request
/// per second. Replace the endpoint configuration with a contracted or
/// self-hosted provider before launch.
class RrydLocationService {
  RrydLocationService({
    http.Client? client,
    this.nominatimBase = 'https://nominatim.openstreetmap.org',
    this.osrmBase = 'https://router.project-osrm.org',
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final String nominatimBase;
  final String osrmBase;

  final Map<String, List<RrydPlaceSearchResult>> _searchCache = {};
  final Map<String, RrydPlaceSearchResult> _reverseCache = {};

  DateTime? _lastGeocoderRequest;

  static const String _userAgent =
      'RrydMobile/0.1 (+https://github.com/bishowkarmasagar21-afk/Rydo-)';

  Future<void> _respectGeocoderRateLimit() async {
    final last = _lastGeocoderRequest;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < const Duration(seconds: 1)) {
        await Future<void>.delayed(const Duration(seconds: 1) - elapsed);
      }
    }
    _lastGeocoderRequest = DateTime.now();
  }

  Future<List<RrydPlaceSearchResult>> searchNepal(String query) async {
    final cleaned = query.trim();
    if (cleaned.length < 3) {
      throw ArgumentError('Enter at least 3 characters to search.');
    }

    final key = cleaned.toLowerCase();
    final cached = _searchCache[key];
    if (cached != null) return cached;

    await _respectGeocoderRateLimit();

    final uri = Uri.parse(nominatimBase).replace(
      path: '/search',
      queryParameters: {
        'q': cleaned,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '5',
        'countrycodes': 'np',
      },
    );

    final response = await _client.get(uri, headers: const {
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw StateError(
        'Location search is unavailable (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) {
      throw const FormatException('Unexpected location-search response.');
    }

    final results = <RrydPlaceSearchResult>[];
    for (final item in decoded) {
      if (item is! Map) continue;
      final latitude = double.tryParse(item['lat']?.toString() ?? '');
      final longitude = double.tryParse(item['lon']?.toString() ?? '');
      final label = item['display_name']?.toString() ?? '';
      final address = item['address'];
      final countryCode = address is Map
          ? address['country_code']?.toString().toLowerCase()
          : null;
      if (latitude == null || longitude == null || label.isEmpty) continue;
      if (countryCode != 'np' || !_isInsideNepal(latitude, longitude)) continue;

      results.add(RrydPlaceSearchResult(
        label: label,
        latitude: latitude,
        longitude: longitude,
      ));
    }

    _searchCache[key] = results;
    return results;
  }

  Future<RrydLocationPoint> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    _requireNepal(latitude, longitude);
    final key = '${latitude.toStringAsFixed(5)},${longitude.toStringAsFixed(5)}';
    final cached = _reverseCache[key];
    if (cached != null) return cached.toPoint();

    await _respectGeocoderRateLimit();

    final uri = Uri.parse(nominatimBase).replace(
      path: '/reverse',
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'format': 'jsonv2',
        'zoom': '18',
      },
    );

    final response = await _client.get(uri, headers: const {
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      throw StateError(
        'Address lookup is unavailable (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected address lookup response.');
    }
    final address = decoded['display_name']?.toString();
    final addressParts = decoded['address'];
    final countryCode = addressParts is Map
        ? addressParts['country_code']?.toString().toLowerCase()
        : null;
    if (address == null || address.isEmpty) {
      throw StateError('No address was found for this map point.');
    }
    if (countryCode != 'np') {
      throw StateError('Choose a location inside Nepal.');
    }

    final result = RrydPlaceSearchResult(
      label: address,
      latitude: latitude,
      longitude: longitude,
    );
    _reverseCache[key] = result;
    return result.toPoint();
  }

  Future<RrydRouteResult> getDrivingRoute({
    required RrydLocationPoint from,
    required RrydLocationPoint to,
  }) async {
    _requireNepal(from.latitude, from.longitude);
    _requireNepal(to.latitude, to.longitude);

    final uri = Uri.parse(
      '$osrmBase/route/v1/driving/'
      '${from.longitude},${from.latitude};'
      '${to.longitude},${to.latitude}',
    ).replace(queryParameters: {
      'overview': 'full',
      'geometries': 'geojson',
      'steps': 'false',
    });

    final response = await _client.get(uri, headers: const {
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    }).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw StateError(
        'Route service is unavailable (HTTP ${response.statusCode}).',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['code'] != 'Ok') {
      throw StateError('No driving route was found between these locations.');
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      throw StateError('The route service returned no usable route.');
    }

    final route = routes.first as Map;
    final distanceMeters = (route['distance'] as num?)?.toDouble();
    final durationSeconds = (route['duration'] as num?)?.toDouble();
    final geometry = route['geometry'];
    if (distanceMeters == null || durationSeconds == null ||
        geometry is! Map || geometry['coordinates'] is! List) {
      throw const FormatException('The route response is incomplete.');
    }

    final points = <LatLng>[];
    for (final pair in geometry['coordinates'] as List) {
      if (pair is! List || pair.length < 2) continue;
      final longitude = (pair[0] as num).toDouble();
      final latitude = (pair[1] as num).toDouble();
      if (!_isInsideNepal(latitude, longitude)) {
        throw StateError('Route geometry left the supported Nepal area.');
      }
      points.add(LatLng(latitude, longitude));
    }
    if (points.length < 2) {
      throw StateError('The route geometry is too short to display.');
    }

    return RrydRouteResult(
      distanceKm: distanceMeters / 1000,
      durationMinutes: (durationSeconds / 60).ceil(),
      points: points,
    );
  }

  Future<RrydLocationPoint> getCurrentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw StateError('Turn on Location Services on your phone and try again.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw StateError('Location permission was not granted.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Location permission is blocked. Enable it in your phone settings.',
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    _requireNepal(position.latitude, position.longitude);

    return reverseGeocode(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  bool _isInsideNepal(double latitude, double longitude) =>
      latitude >= 26 &&
      latitude <= 31 &&
      longitude >= 80 &&
      longitude <= 89;

  void _requireNepal(double latitude, double longitude) {
    if (!_isInsideNepal(latitude, longitude)) {
      throw StateError('Rryd ride locations must be inside Nepal.');
    }
  }

  void dispose() => _client.close();
}
