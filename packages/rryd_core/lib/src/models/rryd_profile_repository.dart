import '../backend/supabase_bootstrap.dart';
import 'rryd_profile.dart';

class RrydProfileRepository {
  Future<RrydProfile> load(String userId) async {
    final row = await SupabaseBootstrap.client
        .from('profiles')
        .select(
          'id,full_name,phone,role,is_verified,is_suspended,is_online',
        )
        .eq('id', userId)
        .maybeSingle();

    if (row == null) {
      throw StateError(
        'The signed-in account has no Rryd profile. '
        'Check the existing handle_new_user trigger and profile RLS.',
      );
    }

    return RrydProfile.fromMap(row);
  }
}
