import '../../../shared/models/action_outcome.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_input_formatters.dart';
import '../../authentication/data/models/auth_profile_model.dart';
import '../data/models/profile_user_model.dart';
import '../data/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(
      this._repository, this._authProfile, this._refreshAuthProfile)
      : super(ProfileState.initial()) {
    loadProfile();
  }

  final ProfileRepository _repository;
  final AuthProfileModel? _authProfile;
  final Future<void> Function() _refreshAuthProfile;

  Future<void> loadProfile() async {
    try {
      final users = _mergeAuthenticatedUser(await _repository.getUsers());
      // Activity logs are permission-gated for non-admin users. A profile
      // should still load when that optional section is unavailable.
      List<ProfileActivityModel> activities;
      try {
        activities = await _repository.getActivities();
      } catch (_) {
        activities = const <ProfileActivityModel>[];
      }

      state = state.copyWith(
        users: users,
        filteredUsers: _filterUsers(
          users,
          state.searchQuery,
          state.userFilter,
        ),
        activities: activities,
        isLoading: false,
        errorMessage: null,
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Unable to load profile workspace.',
      );
    }
  }

  Future<void> refreshProfile() async {
    state = state.copyWith(isLoading: true, successMessage: null);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await loadProfile();
  }

  ProfileUserModel get currentUser {
    return state.users.firstWhere(
      (user) => user.username == _authProfile?.username,
      orElse: () => ProfileUserModel(
        id: _authProfile?.id ?? 'current-user',
        employeeId: 'EMP-000',
        fullName: _authProfile?.fullName ?? 'SeedRover User',
        username: _authProfile?.username ?? 'operator',
        email: _authProfile?.email ?? 'operator@seedrover.local',
        contactNumber: '+63 917 000 0000',
        roleName: _authProfile?.roleName ?? 'Unassigned',
        dateJoined: DateTime(2026, 1, 1),
        status: ProfileAccountStatus.active,
        hasProfilePicture: !state.profilePictureRemoved,
      ),
    );
  }

  ProfileUserModel? userById(String userId) {
    for (final user in state.users) {
      if (user.id == userId) {
        return user;
      }
    }

    return null;
  }

  List<ProfileStatModel> statsForRole(String roleName) {
    final totalUsers = state.users.length;
    final activeUsers = state.users
        .where((user) => user.status == ProfileAccountStatus.active)
        .length;
    final inactiveUsers = state.users
        .where((user) => user.status == ProfileAccountStatus.inactive)
        .length;
    final recentActivities = state.activities.length;

    return switch (roleName) {
      'System Administrator' => [
          ProfileStatModel(
            label: 'Total Users',
            value: '$totalUsers',
            context: 'Live',
            iconKey: 'users',
          ),
          ProfileStatModel(
            label: 'Active Users',
            value: '$activeUsers',
            context: 'Active',
            iconKey: 'active',
          ),
          ProfileStatModel(
            label: 'Pending Accs',
            value: '$inactiveUsers',
            context: 'Review',
            iconKey: 'pending',
          ),
        ],
      'Farm Planting Manager' || 'Planting Staff' => [
          ProfileStatModel(
            label: 'Crops Managed',
            value: '$recentActivities',
            context: 'Active',
            iconKey: 'crops',
          ),
          ProfileStatModel(
            label: 'Planting Sessions',
            value: '5',
            context: 'Week',
            iconKey: 'planting',
          ),
          ProfileStatModel(
            label: "Today's Tasks",
            value: '3',
            context: 'Open',
            iconKey: 'tasks',
          ),
        ],
      'Farm Inventory Manager' || 'Inventory Staff' => [
          ProfileStatModel(
            label: 'Inventory Updates',
            value: '$recentActivities',
            context: 'Week',
            iconKey: 'inventory',
          ),
          ProfileStatModel(
            label: 'Low Inventory Items',
            value: '2',
            context: 'Now',
            iconKey: 'warning',
          ),
          ProfileStatModel(
            label: 'Transactions',
            value: '11',
            context: 'Recent',
            iconKey: 'transactions',
          ),
        ],
      _ => [
          ProfileStatModel(
            label: 'Assigned Tasks',
            value: '$recentActivities',
            context: 'Open',
            iconKey: 'tasks',
          ),
          ProfileStatModel(
            label: 'Activities Done',
            value: '14',
            context: 'Week',
            iconKey: 'active',
          ),
          ProfileStatModel(
            label: 'Notifications',
            value: '4',
            context: 'Unread',
            iconKey: 'notifications',
          ),
        ],
    };
  }

  List<ProfileActivityModel> filteredActivities() {
    final now = DateTime.now();

    return state.activities.where((activity) {
      return switch (state.activityFilter) {
        ProfileActivityFilter.today => _sameDay(activity.timestamp, now),
        ProfileActivityFilter.thisWeek =>
          activity.timestamp.isAfter(now.subtract(const Duration(days: 7))),
        ProfileActivityFilter.thisMonth =>
          activity.timestamp.year == now.year &&
              activity.timestamp.month == now.month,
      };
    }).toList();
  }

  void updateActivityFilter(ProfileActivityFilter filter) {
    state = state.copyWith(activityFilter: filter);
  }

  void updateSearch(String query) {
    state = state.copyWith(
      searchQuery: query,
      filteredUsers: _filterUsers(state.users, query, state.userFilter),
    );
  }

  void updateUserFilter(ProfileUserFilter filter) {
    state = state.copyWith(
      userFilter: filter,
      filteredUsers: _filterUsers(state.users, state.searchQuery, filter),
    );
  }

  Future<ActionOutcome> updateCurrentProfile({
    required String fullName,
    required String contactNumber,
    String? firstName,
    String? middleInitial,
    String? lastName,
  }) async {
    final current = currentUser;
    try {
      final normalizedContact = AppInputFormatters.normalizeContactNumber(
        contactNumber.trim().isEmpty ? current.contactNumber : contactNumber,
        allowLegacy: true,
      ) ?? '';
      final updatedUser = current.copyWith(
        fullName: fullName.trim().isEmpty ? current.fullName : fullName.trim(),
        contactNumber: normalizedContact,
      );
      final savedUser = await _repository.updateCurrentProfile(
        profileId: current.id,
        fullName: updatedUser.fullName,
        contactNumber: updatedUser.contactNumber,
        firstName: firstName,
        middleInitial: middleInitial,
        lastName: lastName,
      );
      final users = [
        for (final user in state.users)
          if (user.id == savedUser.id)
            savedUser
          else
            user,
      ];

      state = state.copyWith(
        users: users,
        filteredUsers: _filterUsers(users, state.searchQuery, state.userFilter),
        successMessage: 'Profile updated.',
      );
      try {
        await _refreshAuthProfile();
      } catch (_) {/* Saved; refresh can be retried. */}
    } catch (error) {
      final message = error is FormatException
          ? error.message
          : 'Unable to update profile.';
      state = state.copyWith(errorMessage: message);
      return ActionOutcome.failure(
          state.errorMessage ?? 'Unable to save changes.');
    }
    return const ActionOutcome.success();
  }

  Future<ActionOutcome> changeProfilePicture(ProfileImageUpload upload) async {
    final current = currentUser;

    try {
      final savedUser = await _repository.updateProfileImage(
        profileId: current.id,
        upload: upload,
      );
      _replaceUser(
        savedUser,
        successMessage: 'Profile picture updated.',
      );
    } catch (_) {
      state = state.copyWith(errorMessage: 'Unable to update profile picture.');
      return ActionOutcome.failure(
          state.errorMessage ?? 'Unable to save changes.');
    }
    return const ActionOutcome.success();
  }

  Future<ActionOutcome> removeProfilePicture() async {
    final current = currentUser;

    try {
      final savedUser = await _repository.removeProfileImage(current.id);
      _replaceUser(
        savedUser.copyWith(hasProfilePicture: false),
        successMessage: 'Profile picture removed.',
      );
    } catch (_) {
      state = state.copyWith(errorMessage: 'Unable to remove profile picture.');
      return ActionOutcome.failure(
          state.errorMessage ?? 'Unable to save changes.');
    }
    return const ActionOutcome.success();
  }

  void _replaceUser(
    ProfileUserModel user, {
    required String successMessage,
  }) {
    final users = [
      for (final item in state.users)
        if (item.id == user.id) user else item,
    ];

    state = state.copyWith(
      users: users,
      filteredUsers: _filterUsers(users, state.searchQuery, state.userFilter),
      profilePictureRemoved: !user.hasProfilePicture,
      successMessage: successMessage,
    );
  }

  void clearMessages() {
    state = state.copyWith(
      successMessage: null,
      errorMessage: null,
    );
  }

  List<ProfileUserModel> _mergeAuthenticatedUser(
    List<ProfileUserModel> users,
  ) {
    final authProfile = _authProfile;

    if (authProfile == null) {
      return users;
    }

    ProfileUserModel? existingUser;
    for (final user in users) {
      if (user.username == authProfile.username) {
        existingUser = user;
        break;
      }
    }

    final current = ProfileUserModel(
      id: authProfile.id,
      employeeId: existingUser?.employeeId ?? 'EMP-000',
      fullName: existingUser?.fullName ?? authProfile.fullName,
      username: authProfile.username,
      email: existingUser?.email ?? authProfile.email,
      contactNumber: existingUser?.contactNumber ?? '+63 917 000 0000',
      roleName: authProfile.roleName,
      dateJoined: existingUser?.dateJoined ?? DateTime(2026, 1, 1),
      status: authProfile.isActive
          ? ProfileAccountStatus.active
          : ProfileAccountStatus.inactive,
      profileImagePath: existingUser?.profileImagePath,
      profileImageUrl: existingUser?.profileImageUrl,
      hasProfilePicture:
          existingUser?.hasProfilePicture ?? !state.profilePictureRemoved,
    );

    return [
      current,
      ...users.where((user) => user.username != authProfile.username),
    ];
  }

  List<ProfileUserModel> _filterUsers(
    List<ProfileUserModel> users,
    String query,
    ProfileUserFilter filter,
  ) {
    final normalizedQuery = query.trim().toLowerCase();

    return users.where((user) {
      final matchesSearch = normalizedQuery.isEmpty ||
          user.fullName.toLowerCase().contains(normalizedQuery) ||
          user.username.toLowerCase().contains(normalizedQuery) ||
          user.roleName.toLowerCase().contains(normalizedQuery);
      final matchesFilter = switch (filter) {
        ProfileUserFilter.all => true,
        ProfileUserFilter.active => user.status == ProfileAccountStatus.active,
        ProfileUserFilter.inactive =>
          user.status == ProfileAccountStatus.inactive,
        ProfileUserFilter.administrator =>
          user.roleName == 'System Administrator',
        ProfileUserFilter.plantingManager =>
          user.roleName == 'Farm Planting Manager',
        ProfileUserFilter.inventoryManager =>
          user.roleName == 'Farm Inventory Manager',
        ProfileUserFilter.farmStaff => user.roleName == 'Planting Staff' ||
            user.roleName == 'Inventory Staff',
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}
