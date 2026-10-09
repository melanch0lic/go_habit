import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Client configuration from the bundled `.env` (see `.env.example`).
///
/// Only public values belong here: the Supabase URL and the publishable (anon) key.
/// Never put a service-role key or database password into the app.
class EnvConfig {
  static String get supabaseUrl => _value('SUPABASE_URL');

  /// New Supabase projects issue publishable keys (`sb_publishable_...`); older ones an anon JWT.
  static String get supabaseKey =>
      _value('SUPABASE_PUBLISHABLE_KEY').isNotEmpty ? _value('SUPABASE_PUBLISHABLE_KEY') : _value('SUPABASE_ANON_KEY');

  static String _value(String key) => (dotenv.maybeGet(key) ?? '').trim();

  /// Fails fast with an actionable message instead of a confusing network error later.
  static void validate() {
    final problems = [
      if (Uri.tryParse(supabaseUrl)?.hasScheme != true) 'SUPABASE_URL is missing or invalid',
      if (supabaseKey.isEmpty) 'SUPABASE_PUBLISHABLE_KEY (or SUPABASE_ANON_KEY) is missing',
    ];
    if (problems.isNotEmpty) {
      throw StateError('Invalid .env configuration: ${problems.join('; ')}. See .env.example.');
    }
  }
}
