import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/data/models/auth_profile_model.dart';
import '../data/models/profile_user_model.dart';
import '../data/repositories/profile_repository.dart';
import 'profile_state.dart';

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._repository, this._authProfile)
      : super(ProfileState.initial()) {
    loadProfile();
  }

  final ProfileRepository _repository;
  final AuthProfileModel? _authProfile;

  void loadProfile() {
    try {
      final users = _mergeAuthenticatedUser(_repository.getUsers());
      final activities = _repository.getActivities(
        _authProfile?.roleName ?? 'Farm Staff',
      );

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
    loadProfile();
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
        roleName: _authProfile?.roleName ?? 'Farm Staff',
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
    return switch (roleName) {
      'System Administrator' => const [
          ProfileStatModel(
            label: 'Total Users',
            value: '12',
            context: 'Mock',
            iconKey: 'users',
          ),
          ProfileStatModel(
            label: 'Active Users',
            value: '9',
            context: 'Active',
            iconKey: 'active',
          ),
          ProfileStatModel(
            label: 'Pending Accs',
            value: '2',
            context: 'Review',
            iconKey: 'pending',
          ),
        ],
      'Farm Planting Manager' => const [
          ProfileStatModel(
            label: 'Crops Managed',
            value: '12',
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
      'Farm Inventory Manager' => const [
          ProfileStatModel(
            label: 'Inventory Updates',
            value: '18',
            context: 'Week',
            iconKey: 'inventory',
          ),
          ProfileStatModel(
            label: 'Low Stock Items',
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
      _ => const [
          ProfileStatModel(
            label: 'Assigned Tasks',
            value: '6',
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
        ProfileActivityFilter.today =>
          _sameDay(activity.timestamp, now),
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

  void updateCurrentProfile({
    required String fullName,
    required String contactNumber,
  }) {
    final current = currentUser;
    updateUser(
      current.copyWith(
        fullName: fullName.trim().isEmpty ? current.fullName : fullName.trim(),
        contactNumber: contactNumber.trim().isEmpty
            ? current.contactNumber
            : contactNumber.trim(),
      ),
      successMessage: 'Profile updated.',
    );
  }

  void changePassword() {
    state = state.copyWith(successMessage: 'Password changed in mock mode.');
  }

  void changeProfilePicture() {
    state = state.copyWith(
      profilePictureRemoved: false,
      successMessage: 'Profile picture changed in mock mode.',
    );
  }

  void removeProfilePicture() {
    state = state.copyWith(
      profilePictureRemoved: true,
      successMessage: 'Profile picture removed in mock mode.',
    );
  }

  void createUser({
    required String fullName,
    required String username,
    required String email,
    required String contactNumber,
    required String roleName,
  }) {
    final generatedPassword = _temporaryPassword(username);
    final nextNumber = state.users.length + 1;
    final user = ProfileUserModel(
      id: 'user-${(nextNumber + 10).toString().padLeft(3, '0')}',
      employeeId: 'EMP-${(nextNumber + 50).toString().padLeft(3, '0')}',
      fullName: fullName.trim(),
      username: username.trim(),
      email: email.trim(),
      contactNumber: contactNumber.trim(),
      roleName: roleName,
      dateJoined: DateTime.now(),
      status: ProfileAccountStatus.active,
    );
    final users = [user, ...state.users];

    state = state.copyWith(
      users: users,
      filteredUsers: _filterUsers(users, state.searchQuery, state.userFilter),
      generatedPassword: generatedPassword,
      successMessage: 'User created. Temporary password generated.',
    );
  }

  void updateUser(
    ProfileUserModel updatedUser, {
    String successMessage = 'User updated.',
  }) {
    final users = [
      for (final user in state.users)
        if (user.id == updatedUser.id) updatedUser else user,
    ];

    state = state.copyWith(
      users: users,
      filteredUsers: _filterUsers(users, state.searchQuery, state.userFilter),
      successMessage: successMessage,
    );
  }

  void resetPassword(String userId) {
    state = state.copyWith(
      generatedPassword: _temporaryPassword(userById(userId)?.username ?? 'user'),
      successMessage: 'Temporary password generated.',
    );
  }

  void deleteUser(String userId) {
    final users = state.users.where((user) => user.id != userId).toList();
    state = state.copyWith(
      users: users,
      filteredUsers: _filterUsers(users, state.searchQuery, state.userFilter),
      successMessage: 'User deleted.',
    );
  }

  void clearMessages() {
    state = state.copyWith(
      successMessage: null,
      generatedPassword: null,
    );
  }

  List<ProfileUserModel> _mergeAuthenticatedUser(
    List<ProfileUserModel> users,
  ) {
    final authProfile = _authProfile;

    if (authProfile == null) {
      return users;
    }

    final current = ProfileUserModel(
      id: authProfile.id,
      employeeId: 'EMP-000',
      fullName: authProfile.fullName,
      username: authProfile.username,
      email: authProfile.email,
      contactNumber: '+63 917 000 0000',
      roleName: authProfile.roleName,
      dateJoined: DateTime(2026, 1, 1),
      status: authProfile.isActive
          ? ProfileAccountStatus.active
          : ProfileAccountStatus.inactive,
      hasProfilePicture: !state.profilePictureRemoved,
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
        ProfileUserFilter.farmStaff => user.roleName == 'Farm Staff',
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  bool _sameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _temporaryPassword(String username) {
    final base = username.trim().isEmpty ? 'seedrover' : username.trim();

    return '${base.split('.').first}#2026';
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return const ProfileRepository();
});
