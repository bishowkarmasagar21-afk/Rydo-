import '../backend/supabase_bootstrap.dart';

class RrydRatingsRepository {
  Future<Set<String>> loadMyRatedRideIds(String userId) async {
    final rows = await SupabaseBootstrap.client
        .from('ride_ratings')
        .select('ride_id')
        .eq('reviewer_id', userId);

    return rows
        .map((row) => row['ride_id'].toString())
        .toSet();
  }

  Future<void> submitRating({
    required int rideId,
    required int rating,
    String? feedback,
  }) async {
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5.');
    }
    final clean = feedback?.trim();
    if (clean != null && clean.length > 1000) {
      throw ArgumentError('Feedback must be at most 1000 characters.');
    }

    await SupabaseBootstrap.client.rpc(
      'rryd_submit_ride_rating',
      params: {
        'p_ride_id': rideId,
        'p_rating': rating,
        'p_feedback': clean == null || clean.isEmpty ? null : clean,
      },
    );
  }
}
