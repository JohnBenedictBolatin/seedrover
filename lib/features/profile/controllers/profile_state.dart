import '../data/models/profile_user_model.dart';

class ProfileState {
  const ProfileState({
    required this.users,
    required this.filteredUsers,
    required this.activities,
    required this.searchQuery,
    required this.userFilter,
    required this.activityFilter,
    required this.isLoading,
    required this.successMessage,
    required this.errorMessage,
    required this.generatedPassword,
    required this.profilePictureRemoved,
  });

  factory ProfileState.initial() {
    return const ProfileState(
      users: [],
      filteredUsers: [],
      activities: [],
      searchQuery: '',
      userFilter: ProfileUserFilter.all,
      activityFilter: ProfileActivityFilter.today,
      isLoading: true,
      successMessage: null,
      errorMessage: null,
      generatedPassword: null,
      profilePictureRemoved: false,
    );
  }

  final List<ProfileUserModel> users;
  final List<ProfileUserModel> filteredUsers;
  final List<ProfileActivityModel> activities;
  final String searchQuery;
  final ProfileUserFilter userFilter;
  final ProfileActivityFilter activityFilter;
  final bool isLoading;
  final String? successMessage;
  final String? errorMessage;
  final String? generatedPassword;
  final bool profilePictureRemoved;

  ProfileState copyWith({
    List<ProfileUserModel>? users,
    List<ProfileUserModel>? filteredUsers,
    List<ProfileActivityModel>? activities,
    String? searchQuery,
    ProfileUserFilter? userFilter,
    ProfileActivityFilter? activityFilter,
    bool? isLoading,
    Object? successMessage = _noChange,
    Object? errorMessage = _noChange,
    Object? generatedPassword = _noChange,
    bool? profilePictureRemoved,
  }) {
    return ProfileState(
      users: users ?? this.users,
      filteredUsers: filteredUsers ?? this.filteredUsers,
      activities: activities ?? this.activities,
      searchQuery: searchQuery ?? this.searchQuery,
      userFilter: userFilter ?? this.userFilter,
      activityFilter: activityFilter ?? this.activityFilter,
      isLoading: isLoading ?? this.isLoading,
      successMessage: successMessage == _noChange
          ? this.successMessage
          : successMessage as String?,
      errorMessage: errorMessage == _noChange
          ? this.errorMessage
          : errorMessage as String?,
      generatedPassword: generatedPassword == _noChange
          ? this.generatedPassword
          : generatedPassword as String?,
      profilePictureRemoved:
          profilePictureRemoved ?? this.profilePictureRemoved,
    );
  }
}

const _noChange = Object();
