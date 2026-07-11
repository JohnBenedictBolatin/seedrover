import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/database_tables.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/auth_permission_model.dart';
import '../models/auth_profile_model.dart';

class AuthRepository {
  const AuthRepository(this._client);

  final SupabaseClient _client;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Session? get currentSession => _client.auth.currentSession;

  Future<AuthProfileModel?> getCurrentProfile() async {
    final userId = _client.auth.currentUser?.id;

    if (userId == null) {
      return null;
    }

    return _fetchProfile(userId);
  }

  Future<AuthProfileModel> signInWithUsername({
    required String username,
    required String password,
  }) async {
    final email = await _resolveEmail(username);

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        throw const AppException('Unable to sign in. Please try again.');
      }

      final profile = await _fetchProfile(user.id);
      await _recordActivity(
        userId: user.id,
        activity: 'Login',
        description: '${profile.username} signed in.',
      );

      return profile;
    } on AuthException {
      throw const AppException('Incorrect password. Please try again.');
    }
  }

  Future<void> signOut() async {
    final userId = _client.auth.currentUser?.id;

    if (userId != null) {
      await _recordActivity(
        userId: userId,
        activity: 'Logout',
        description: 'User signed out.',
      );
    }

    await _client.auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String username) async {
    final email = await _resolveEmail(username);

    await _client.auth.resetPasswordForEmail(email);
  }

  Future<String> _resolveEmail(String username) async {
    final normalizedUsername = username.trim();

    if (normalizedUsername.isEmpty) {
      throw const AppException('Enter your username.');
    }

    final response = await _client.rpc<String?>(
      'get_email_by_username',
      params: {'requested_username': normalizedUsername},
    );

    if (response == null || response.isEmpty) {
      throw const AppException(
        'Username not found or the account is inactive.',
      );
    }

    return response;
  }

  Future<AuthProfileModel> _fetchProfile(String userId) async {
    final profileJson = await _client
        .from(DatabaseTables.profiles)
        .select('id, username, email, full_name, is_active, roles(role_name)')
        .eq('id', userId)
        .single();

    final permissionsJson = await _client
        .from(DatabaseTables.profilePermissions)
        .select('permissions(id, permission_key, module, description)')
        .eq('profile_id', userId) as List<dynamic>;

    final permissions = permissionsJson
        .map<AuthPermissionModel>((row) {
          final permissionRow = row as Map<String, dynamic>;
          final permission =
              permissionRow['permissions'] as Map<String, dynamic>?;

          if (permission == null) {
            throw const AppException('Unable to load user permissions.');
          }

          return AuthPermissionModel.fromJson(permission);
        })
        .toList(growable: false);

    final profile = AuthProfileModel.fromJson(
      profileJson,
      permissions: permissions,
    );

    if (!profile.isActive) {
      await signOut();
      throw const AppException('This account is currently inactive.');
    }

    return profile;
  }

  Future<void> _recordActivity({
    required String userId,
    required String activity,
    required String description,
  }) async {
    await _client.from(DatabaseTables.activityLogs).insert({
      'user_id': userId,
      'activity': activity,
      'description': description,
      'module': 'Authentication',
    });
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseClientProvider)),
);
