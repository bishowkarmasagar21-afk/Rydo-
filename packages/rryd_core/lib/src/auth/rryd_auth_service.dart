import 'package:supabase_flutter/supabase_flutter.dart';

import '../backend/supabase_bootstrap.dart';

class RrydAuthService {
  SupabaseClient get _client => SupabaseBootstrap.client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<AuthResponse> registerPassenger({
    required String fullName,
    required String phone,
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'role': 'passenger',
      },
      emailRedirectTo: 'com.rryd.passenger://auth-callback',
    );
  }

  Future<void> requestPasswordReset({
    required String email,
    required String appScheme,
  }) {
    return _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: appScheme + '://auth-callback',
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
