import '../backend/supabase_bootstrap.dart';
import '../models/rryd_location.dart';

class RrydFareRule {
  const RrydFareRule({
    required this.vehicleType,
    required this.baseFare,
    required this.perKmFare,
    required this.commissionPercent,
  });

  final String vehicleType;
  final double baseFare;
  final double perKmFare;
  final double commissionPercent;

  int estimate(double distanceKm) =>
      (baseFare + perKmFare * distanceKm).floor() +
      ((baseFare + perKmFare * distanceKm) -
                  (baseFare + perKmFare * distanceKm).floor() >=
              0.5
          ? 1
          : 0);

  factory RrydFareRule.fromMap(Map<String, dynamic> row) => RrydFareRule(
        vehicleType: row['vehicle_type'].toString(),
        baseFare: (row['base_fare'] as num).toDouble(),
        perKmFare: (row['per_km_fare'] as num).toDouble(),
        commissionPercent:
            (row['platform_commission_percent'] as num?)?.toDouble() ?? 0,
      );
}

class RrydPassengerRideRepository {
  Future<List<RrydFareRule>> loadActiveFareRules() async {
    final rows = await SupabaseBootstrap.client
        .from('fare_rules')
        .select(
          'vehicle_type,base_fare,per_km_fare,platform_commission_percent',
        )
        .eq('is_active', true);

    return rows
        .map((row) => RrydFareRule.fromMap(row))
        .where((rule) =>
            const ['bike', 'car', 'tuk_tuk'].contains(rule.vehicleType))
        .toList(growable: false);
  }

  Future<int> checkVehicleAvailability(String vehicleType) async {
    final response = await SupabaseBootstrap.client.rpc(
      'rryd_check_vehicle_availability',
      params: {'p_vehicle_type': vehicleType},
    );

    if (response is int) return response;
    if (response is String) {
      final parsed = int.tryParse(response);
      if (parsed != null) return parsed;
    }
    if (response is List && response.isNotEmpty && response.first is Map) {
      final first = (response.first as Map).values.first;
      final parsed = int.tryParse(first.toString());
      if (parsed != null) return parsed;
    }
    if (response is Map) {
      for (final key in ['available_count', 'count', 'total']) {
        final parsed = int.tryParse(response[key]?.toString() ?? '');
        if (parsed != null) return parsed;
      }
    }
    throw const FormatException(
      'The availability function returned an unsupported result.',
    );
  }

  Future<dynamic> requestRide({
    required RrydLocationPoint pickup,
    required RrydLocationPoint destination,
    required String vehicleType,
    required double distanceKm,
    required String paymentMethod,
  }) {
    if (!pickup.isInsideNepal || !destination.isInsideNepal) {
      throw ArgumentError('Both ride locations must be inside Nepal.');
    }
    if (distanceKm <= 0 || distanceKm > 500) {
      throw ArgumentError('The calculated route distance is not valid.');
    }
    if (paymentMethod != 'cash') {
      throw StateError(
        'Online payments are not connected yet. No online payment was taken.',
      );
    }

    return SupabaseBootstrap.client.rpc(
      'request_ride',
      params: {
        'p_pickup_location': pickup.label,
        'p_destination': destination.label,
        'p_vehicle_type': vehicleType,
        'p_distance_km': double.parse(distanceKm.toStringAsFixed(3)),
        'p_payment_method': paymentMethod,
        'p_pickup_latitude': pickup.latitude,
        'p_pickup_longitude': pickup.longitude,
        'p_destination_latitude': destination.latitude,
        'p_destination_longitude': destination.longitude,
      },
    );
  }

  Future<List<Map<String, dynamic>>> loadMyRides(String passengerId) async {
    final rows = await SupabaseBootstrap.client
        .from('rides')
        .select('*')
        .eq('passenger_id', passengerId)
        .order('created_at', ascending: false)
        .limit(50);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> cancelRide(int rideId) async {
    final result = await SupabaseBootstrap.client.rpc(
      'cancel_ride',
      params: {'p_ride_id': rideId},
    );
    if (result == false) {
      throw StateError('The server did not confirm ride cancellation.');
    }
  }
}
