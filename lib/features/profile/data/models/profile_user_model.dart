enum ProfileAccountStatus {
  active,
  inactive,
  suspended;

  String get label {
    return switch (this) {
      ProfileAccountStatus.active => 'Active',
      ProfileAccountStatus.inactive => 'Inactive',
      ProfileAccountStatus.suspended => 'Suspended',
    };
  }
}

enum ProfileUserFilter {
  all,
  active,
  inactive,
  administrator,
  plantingManager,
  inventoryManager,
  farmStaff;

  String get label {
    return switch (this) {
      ProfileUserFilter.all => 'All Users',
      ProfileUserFilter.active => 'Active',
      ProfileUserFilter.inactive => 'Inactive',
      ProfileUserFilter.administrator => 'Admin',
      ProfileUserFilter.plantingManager => 'Planting',
      ProfileUserFilter.inventoryManager => 'Inventory',
      ProfileUserFilter.farmStaff => 'Staff',
    };
  }
}

enum ProfileActivityFilter {
  today,
  thisWeek,
  thisMonth;

  String get label {
    return switch (this) {
      ProfileActivityFilter.today => 'Today',
      ProfileActivityFilter.thisWeek => 'This Week',
      ProfileActivityFilter.thisMonth => 'This Month',
    };
  }
}

class ProfileUserModel {
  const ProfileUserModel({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.username,
    required this.email,
    required this.contactNumber,
    required this.roleName,
    required this.dateJoined,
    required this.status,
    this.hasProfilePicture = true,
  });

  final String id;
  final String employeeId;
  final String fullName;
  final String username;
  final String email;
  final String contactNumber;
  final String roleName;
  final DateTime dateJoined;
  final ProfileAccountStatus status;
  final bool hasProfilePicture;

  bool get isOnline => status == ProfileAccountStatus.active;

  ProfileUserModel copyWith({
    String? fullName,
    String? contactNumber,
    String? roleName,
    ProfileAccountStatus? status,
    bool? hasProfilePicture,
  }) {
    return ProfileUserModel(
      id: id,
      employeeId: employeeId,
      fullName: fullName ?? this.fullName,
      username: username,
      email: email,
      contactNumber: contactNumber ?? this.contactNumber,
      roleName: roleName ?? this.roleName,
      dateJoined: dateJoined,
      status: status ?? this.status,
      hasProfilePicture: hasProfilePicture ?? this.hasProfilePicture,
    );
  }
}

class ProfileActivityModel {
  const ProfileActivityModel({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.module,
  });

  final String title;
  final String description;
  final DateTime timestamp;
  final String module;
}

class ProfileStatModel {
  const ProfileStatModel({
    required this.label,
    required this.value,
    required this.context,
    required this.iconKey,
  });

  final String label;
  final String value;
  final String context;
  final String iconKey;
}
