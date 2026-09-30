import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase configuration constants.
/// Credentials are read from `.env` file or environment variables at runtime.
class SupabaseConfig {
  static String get supabaseUrl =>
      dotenv.env['SUPABASE_URL'] ??
      const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: '',
      );

  static String get supabaseAnonKey =>
      dotenv.env['SUPABASE_ANON_KEY'] ??
      const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: '',
      );
}

