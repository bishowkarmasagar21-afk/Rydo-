import 'package:supabase_flutter/supabase_flutter.dart';

/// Initializes Supabase from build-time values.
///
/// Pass values with:
/// --dart-define=SUPABASE_URL=https://your-project.supabase.co
/// --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
///
/// Only a publishable/anon key belongs in a mobile client. Never use a
/// Supabase secret or service-role key in an app.
class SupabaseBootstrap {
  SupabaseBootstrap._();

  static const String _url =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY', defaultValue: '');

  static bool _initialized = false;

  static bool get isConfigured =>
      _url.startsWith('https://') && _publishableKey.startsWith('sb_publishable_');

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized || !isConfigured) return;

    await Supabase.initialize(
      url: _url,
      publishableKey: _publishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    _initialized = true;
  }

  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'Supabase is not configured. Add SUPABASE_URL and '
        'SUPABASE_PUBLISHABLE_KEY as build-time values.',
      );
    }
    return Supabase.instance.client;
  }
}
