import '../backend/supabase_bootstrap.dart';

class RrydDriverRepository {
  Future<List<Map<String, dynamic>>> loadVehicles(String driverId) async {
    final rows = await SupabaseBootstrap.client
        .from('vehicles')
        .select('*')
        .eq('driver_id', driverId)
        .order('id', ascending: false);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadRideRequests() async {
    final rows = await SupabaseBootstrap.client
        .from('rides')
        .select('*')
        .eq('status', 'requested')
        .isFilter('driver_id', null)
        .order('created_at', ascending: false)
        .limit(40);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> loadMyRides(String driverId) async {
    final rows = await SupabaseBootstrap.client
        .from('rides')
        .select('*')
        .eq('driver_id', driverId)
        .order('created_at', ascending: false)
        .limit(250);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<bool> setOnline(bool online) async {
    final result = await SupabaseBootstrap.client.rpc(
      'set_driver_online',
      params: {'p_online': online},
    );
    if (result == false) {
      throw StateError(
        'The server refused the online-status change. Check verification, '
        'account status and approved vehicles.',
      );
    }
    if (result != true) {
      throw StateError('The server did not confirm the online-status change.');
    }
    return result;
  }

  Future<void> updateLocation({
    required double latitude,
    required double longitude,
  }) async {
    final result = await SupabaseBootstrap.client.rpc(
      'update_driver_location',
      params: {
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
    if (result == false) {
      throw StateError('The server did not confirm the location update.');
    }
  }

  Future<Map<String, dynamic>?> loadPassengerDetailsForRide(
    int rideId,
  ) async {
    final response = await SupabaseBootstrap.client.rpc(
      'get_passenger_details_for_my_ride',
      params: {'p_ride_id': rideId},
    );
    if (response == null) return null;
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    return null;
  }

  Future<Map<String, dynamic>?> loadPassengerLocationForRide(
    int rideId,
  ) async {
    final response = await SupabaseBootstrap.client.rpc(
      'get_passenger_location_for_my_ride',
      params: {'p_ride_id': rideId},
    );
    if (response == null) return null;
    if (response is Map) return Map<String, dynamic>.from(response);
    if (response is List && response.isNotEmpty && response.first is Map) {
      return Map<String, dynamic>.from(response.first as Map);
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> loadRideMessages(int rideId) async {
    final rows = await SupabaseBootstrap.client
        .from('ride_messages')
        .select('*')
        .eq('ride_id', rideId)
        .order('created_at', ascending: true)
        .limit(100);
    return rows.cast<Map<String, dynamic>>();
  }

  Future<void> sendRideMessage({
    required int rideId,
    required String senderId,
    required String message,
  }) async {
    await SupabaseBootstrap.client.from('ride_messages').insert({
      'ride_id': rideId,
      'sender_id': senderId,
      'message': message.trim(),
    });
  }

  Future<void> registerVehicle({
    required String driverId,
    required String vehicleType,
    required String vehicleModel,
    required String vehicleNumber,
  }) async {
    await SupabaseBootstrap.client.from('vehicles').insert({
      'driver_id': driverId,
      'vehicle_type': vehicleType,
      'vehicle_model': vehicleModel.trim(),
      'vehicle_number': vehicleNumber.trim(),
    });
  }

  Future<void> acceptRide(int rideId) async {
    final result = await SupabaseBootstrap.client.rpc(
      'accept_ride',
      params: {'p_ride_id': rideId},
    );
    final accepted = result == true ||
        (result is Map &&
            (result['success'] == true || result['accepted'] == true));
    if (!accepted) {
      throw StateError(
        'The database did not confirm acceptance. The request may already '
        'be assigned or driver eligibility may have changed.',
      );
    }
  }

  Future<void> runRideAction({
    required String action,
    required int rideId,
  }) async {
    const permitted = {
      'driver_arriving',
      'start_ride',
      'complete_ride',
      'cancel_ride',
    };
    if (!permitted.contains(action)) {
      throw ArgumentError('Unsupported ride action.');
    }

    final result = await SupabaseBootstrap.client.rpc(
      action,
      params: {'p_ride_id': rideId},
    );
    // Existing Rryd web portal treats a successful non-error RPC response
    // as submitted unless the function explicitly returns false.
    if (result == false) {
      throw StateError('The server did not confirm this ride action.');
    }
  }
}
