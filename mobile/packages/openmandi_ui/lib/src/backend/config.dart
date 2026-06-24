/// Backend configuration, supplied at build/run time via --dart-define so no
/// secrets live in source. The anon key is safe on the client (RLS protects
/// data); never ship the service-role key.
///
///   flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///               --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// When both are empty the apps run in offline demo mode (in-memory seed),
/// so the project never breaks just because credentials aren't set yet.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Optional Phase-2 Express service base URL (Razorpay/Aadhaar/price cron).
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Google Maps Platform API key.
  static const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  /// Master switch for all location features (GPS, location picker, distance,
  /// "Near me"). Disabled for now. Re-enable by flipping this to true or
  /// passing --dart-define=LOCATION_ENABLED=true.
  static const locationEnabled =
      bool.fromEnvironment('LOCATION_ENABLED', defaultValue: false);

  /// True when real Supabase credentials are provided → live mode.
  /// Accepts both the legacy JWT anon key ("eyJ...") and the newer
  /// publishable key format ("sb_publishable_...").
  static bool get isLive =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
