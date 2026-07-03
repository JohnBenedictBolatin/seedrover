import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
  });

  factory AppEnvironment.fromDotEnv(Map<String, String> values) {
    final supabaseUrl = values['SUPABASE_URL'];
    final supabaseAnonKey = values['SUPABASE_ANON_KEY'];

    if (supabaseUrl == null || supabaseUrl.isEmpty) {
      throw const AppEnvironmentException('SUPABASE_URL is not configured.');
    }

    if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
      throw const AppEnvironmentException(
        'SUPABASE_ANON_KEY is not configured.',
      );
    }

    return AppEnvironment(
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
    );
  }

  final String supabaseUrl;
  final String supabaseAnonKey;
}

class AppEnvironmentException implements Exception {
  const AppEnvironmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => throw UnimplementedError('AppEnvironment has not been initialized.'),
);
