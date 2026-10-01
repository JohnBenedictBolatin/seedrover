import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.roverToken,
    required this.roverBaseUrl,
    required this.cameraBaseUrl,
    this.webAdminUrl = '',
  });

  factory AppEnvironment.fromValues(Map<String, String> values) {
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
      roverToken: values['ROVER_TOKEN']?.trim() ?? '',
      roverBaseUrl: values['ROVER_BASE_URL']?.trim() ?? '',
      cameraBaseUrl: values['CAMERA_BASE_URL']?.trim() ?? '',
      webAdminUrl: values['WEB_ADMIN_URL']?.trim() ?? '',
    );
  }

  factory AppEnvironment.fromDartDefines() => AppEnvironment.fromValues({
        'SUPABASE_URL': const String.fromEnvironment('SUPABASE_URL'),
        'SUPABASE_ANON_KEY': const String.fromEnvironment('SUPABASE_ANON_KEY'),
        'ROVER_TOKEN': const String.fromEnvironment('ROVER_TOKEN'),
        'ROVER_BASE_URL': const String.fromEnvironment('ROVER_BASE_URL'),
        'CAMERA_BASE_URL': const String.fromEnvironment('CAMERA_BASE_URL'),
        'WEB_ADMIN_URL': const String.fromEnvironment('WEB_ADMIN_URL'),
      });

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String roverToken;
  final String roverBaseUrl;
  final String cameraBaseUrl;
  final String webAdminUrl;
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
