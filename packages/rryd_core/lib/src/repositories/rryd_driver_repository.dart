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
    if (result == false) {
      throw StateError('The server did not confirm this ride action.');
    }
    if (result != true && result is! Map && result is! List) {
      throw StateError('The server returned an unexpected ride-action result.');
    }
  }
}
