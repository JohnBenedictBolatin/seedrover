import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/database_tables.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/profile_user_model.dart';

class ProfileRepository {
  const ProfileRepository(this._client);

  static const _profileImagesBucket = 'profile-images';

  final SupabaseClient _client;

  Future<List<ProfileUserModel>> getUsers() async {
    final rows = await _client
        .from(DatabaseTables.profiles)
        .select(
          'id, username, email, full_name, profile_image_path, is_active, created_at, roles(role_name)',
        )
        .order('created_at', ascending: false) as List<dynamic>;

    return rows
        .map((row) => _userFromRow(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<ProfileActivityModel>> getActivities() async {
    final rows = await _client
        .from(DatabaseTables.activityLogs)
        .select('activity, description, module, created_at')
        .order('created_at', ascending: false)
        .limit(30) as List<dynamic>;

    return rows.map((row) {
      final data = row as Map<String, dynamic>;

      return ProfileActivityModel(
        title: data['activity'] as String? ?? 'SeedRover Activity',
        description: data['description'] as String? ?? 'Activity recorded.',
        timestamp: _parseDate(data['created_at']) ?? DateTime.now(),
        module: data['module'] as String? ?? 'System',
      );
    }).toList(growable: false);
  }

  Future<ProfileUserModel> updateUser(ProfileUserModel user) async {
    final roleId = await _roleIdFor(user.roleName);
    final row = await _client
        .from(DatabaseTables.profiles)
        .update({
          'full_name': user.fullName,
          'role_id': roleId,
          'is_active': user.status == ProfileAccountStatus.active,
        })
        .eq('id', user.id)
        .select(
          'id, username, email, full_name, profile_image_path, is_active, created_at, roles(role_name)',
        )
        .single();

    await recordActivity(
      activity: 'User Updated',
      description: '${user.fullName} profile updated.',
      module: 'Users',
    );

    return _userFromRow(row);
  }

  Future<ProfileUserModel> updateCurrentProfile({
    required String profileId,
    required String fullName,
  }) async {
    final row = await _client
        .from(DatabaseTables.profiles)
        .update({'full_name': fullName})
        .eq('id', profileId)
        .select(
          'id, username, email, full_name, profile_image_path, is_active, created_at, roles(role_name)',
        )
        .single();

    await recordActivity(
      activity: 'Profile Updated',
      description: 'Profile information updated.',
      module: 'Profile',
    );

    return _userFromRow(row);
  }

  Future<ProfileUserModel> updateProfileImage({
    required String profileId,
    required ProfileImageUpload upload,
  }) async {
    final imagePath = await _uploadProfileImage(
      profileId: profileId,
      upload: upload,
    );
    final row = await _client
        .from(DatabaseTables.profiles)
        .update({'profile_image_path': imagePath})
        .eq('id', profileId)
        .select(
          'id, username, email, full_name, profile_image_path, is_active, created_at, roles(role_name)',
        )
        .single();

    await recordActivity(
      activity: 'Profile Picture Updated',
      description: 'Profile picture updated.',
      module: 'Profile',
    );

    return _userFromRow(row);
  }

  Future<ProfileUserModel> removeProfileImage(String profileId) async {
    final current = await _client
        .from(DatabaseTables.profiles)
        .select('profile_image_path')
        .eq('id', profileId)
        .single();
    final imagePath = current['profile_image_path'] as String?;

    if (imagePath != null && imagePath.trim().isNotEmpty) {
      await _client.storage.from(_profileImagesBucket).remove([imagePath]);
    }

    final row = await _client
        .from(DatabaseTables.profiles)
        .update({'profile_image_path': null})
        .eq('id', profileId)
        .select(
          'id, username, email, full_name, profile_image_path, is_active, created_at, roles(role_name)',
        )
        .single();

    await recordActivity(
      activity: 'Profile Picture Removed',
      description: 'Profile picture removed.',
      module: 'Profile',
    );

    return _userFromRow(row);
  }

  Future<void> recordActivity({
    required String activity,
    required String description,
    required String module,
  }) async {
    await _client.from(DatabaseTables.activityLogs).insert({
      'user_id': _client.auth.currentUser?.id,
      'activity': activity,
      'description': description,
      'module': module,
    });
  }

  Future<String> _roleIdFor(String roleName) async {
    final row = await _client
        .from(DatabaseTables.roles)
        .select('id')
        .eq('role_name', roleName)
        .single();

    return row['id'] as String;
  }

  ProfileUserModel _userFromRow(Map<String, dynamic> row) {
    final role = row['roles'] as Map<String, dynamic>?;
    final isActive = row['is_active'] as bool? ?? false;
    final imagePath = row['profile_image_path'] as String?;

    return ProfileUserModel(
      id: row['id'] as String,
      employeeId: 'EMP-${(row['id'] as String).substring(0, 8).toUpperCase()}',
      fullName: row['full_name'] as String? ?? 'SeedRover User',
      username: row['username'] as String? ?? 'operator',
      email: row['email'] as String? ?? '',
      contactNumber: '+63 917 000 0000',
      roleName: role?['role_name'] as String? ?? 'Farm Staff',
      dateJoined: _parseDate(row['created_at']) ?? DateTime.now(),
      status:
          isActive ? ProfileAccountStatus.active : ProfileAccountStatus.inactive,
      profileImagePath: imagePath,
      profileImageUrl: _publicProfileImageUrl(imagePath),
      hasProfilePicture: imagePath != null && imagePath.trim().isNotEmpty,
    );
  }

  Future<String> _uploadProfileImage({
    required String profileId,
    required ProfileImageUpload upload,
  }) async {
    final extension = _extensionFor(upload.fileName, upload.mimeType);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final normalizedName = upload.fileName
        .replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '-')
        .toLowerCase();
    final baseName = normalizedName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final path = '$profileId/$timestamp-$baseName.$extension';

    await _client.storage.from(_profileImagesBucket).uploadBinary(
          path,
          upload.bytes,
          fileOptions: FileOptions(
            contentType: upload.mimeType,
            upsert: true,
          ),
        );

    return path;
  }

  String? _publicProfileImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.trim().isEmpty) {
      return null;
    }

    return _client.storage.from(_profileImagesBucket).getPublicUrl(imagePath);
  }

  String _extensionFor(String fileName, String mimeType) {
    final normalizedName = fileName.toLowerCase();

    if (normalizedName.endsWith('.png') || mimeType == 'image/png') {
      return 'png';
    }

    if (normalizedName.endsWith('.webp') || mimeType == 'image/webp') {
      return 'webp';
    }

    return 'jpg';
  }

  DateTime? _parseDate(Object? value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString())?.toLocal();
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(supabaseClientProvider)),
);
