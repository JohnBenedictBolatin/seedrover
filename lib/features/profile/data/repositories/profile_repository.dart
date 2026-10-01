import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/constants/database_tables.dart';
import '../../../../core/constants/shared_workflow_terms.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/app_input_formatters.dart';
import '../models/profile_user_model.dart';

class ProfileRepository {
  const ProfileRepository(this._client);

  static const _profileImagesBucket = 'profile-images';

  final SupabaseClient _client;

  Future<List<ProfileUserModel>> getUsers() async {
    List<dynamic> rows;
    try {
      rows = await _client
          .from(DatabaseTables.profiles)
          .select(
            'id, username, email, full_name, first_name, middle_initial, last_name, contact_number, profile_image_path, is_active, created_at, roles(role_name)',
          )
          .order('created_at', ascending: false) as List<dynamic>;
    } catch (_) {
      // Keep profile loading compatible with projects where the optional
      // contact_number migration has not been applied yet.
      rows = await _client
          .from(DatabaseTables.profiles)
          .select(
            'id, username, email, full_name, first_name, middle_initial, last_name, profile_image_path, is_active, created_at, roles(role_name)',
          )
          .order('created_at', ascending: false) as List<dynamic>;
    }

    return rows
        .map((row) => _userFromRow(row as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<ProfileActivityModel>> getActivities() async {
    final rows = await _client
        .from(DatabaseTables.activityLogs)
        .select(
          'activity, description, module, created_at, actor:profiles!activity_logs_user_id_fkey(full_name)',
        )
        .order('created_at', ascending: false)
        .limit(30) as List<dynamic>;

    return rows.map((row) {
      final data = row as Map<String, dynamic>;
      final activity = data['activity'] as String? ?? 'SeedRover Activity';
      final description =
          data['description'] as String? ?? 'Activity recorded.';
      final actor = data['actor'] as Map<String, dynamic>?;
      final actorName = (actor?['full_name'] as String?)?.trim();

      return ProfileActivityModel(
        title: activity,
        description: activity.toLowerCase() == 'login'
            ? actorName?.isNotEmpty == true
                ? '$actorName signed in.'
                : 'Signed in.'
            : description,
        timestamp: _parseDate(data['created_at']) ?? DateTime.now(),
        module: data['module'] as String? ?? 'System',
      );
    }).toList(growable: false);
  }

  Future<ProfileUserModel> updateCurrentProfile({
    required String profileId,
    required String fullName,
    required String contactNumber,
    String? firstName,
    String? middleInitial,
    String? lastName,
  }) async {
    final normalizedContact = AppInputFormatters.normalizeContactNumber(
      contactNumber,
      allowLegacy: true,
    );
    final row = await _client
        .from(DatabaseTables.profiles)
        .update({
          'full_name': fullName,
          'first_name': firstName,
          'middle_initial': middleInitial,
          'last_name': lastName,
          'contact_number': normalizedContact,
        })
        .eq('id', profileId)
        .select(
          'id, username, email, full_name, first_name, middle_initial, last_name, contact_number, profile_image_path, is_active, created_at, roles(role_name)',
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
          'id, username, email, full_name, first_name, middle_initial, last_name, profile_image_path, is_active, created_at, roles(role_name)',
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
          'id, username, email, full_name, first_name, middle_initial, last_name, profile_image_path, is_active, created_at, roles(role_name)',
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

  ProfileUserModel _userFromRow(Map<String, dynamic> row) {
    final role = row['roles'] as Map<String, dynamic>?;
    final isActive = row['is_active'] as bool? ?? false;
    final imagePath = row['profile_image_path'] as String?;

    return ProfileUserModel(
      id: row['id'] as String,
      employeeId: 'EMP-${(row['id'] as String).substring(0, 8).toUpperCase()}',
      fullName: row['full_name'] as String? ?? 'SeedRover User',
      firstName: row['first_name'] as String?,
      middleInitial: row['middle_initial'] as String?,
      lastName: row['last_name'] as String?,
      username: row['username'] as String? ?? 'operator',
      email: row['email'] as String? ?? '',
      contactNumber: row['contact_number'] as String? ?? '',
      roleName: role?['role_name'] as String? ?? 'Unassigned',
      dateJoined: _parseDate(row['created_at']) ?? DateTime.now(),
      status: isActive
          ? ProfileAccountStatus.active
          : ProfileAccountStatus.inactive,
      profileImagePath: imagePath,
      profileImageUrl: _publicProfileImageUrl(imagePath),
      hasProfilePicture: imagePath != null && imagePath.trim().isNotEmpty,
    );
  }

  Future<String> _uploadProfileImage({
    required String profileId,
    required ProfileImageUpload upload,
  }) async {
    if (upload.bytes.length > SharedWorkflowRules.photoMaxBytes) {
      throw Exception('Profile photos must be 5 MB or smaller.');
    }
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
