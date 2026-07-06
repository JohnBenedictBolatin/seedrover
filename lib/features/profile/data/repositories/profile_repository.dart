import '../models/profile_user_model.dart';

class ProfileRepository {
  const ProfileRepository();

  List<ProfileUserModel> getUsers() {
    return _mockUsers;
  }

  List<ProfileActivityModel> getActivities(String roleName) {
    final now = DateTime.now();

    return [
      ProfileActivityModel(
        title: 'Logged In',
        description: 'Session restored for SeedRover access.',
        timestamp: now.subtract(const Duration(minutes: 12)),
        module: 'System',
      ),
      ProfileActivityModel(
        title: roleName == 'Farm Inventory Manager'
            ? 'Updated Inventory'
            : 'Updated Crop',
        description: roleName == 'Farm Inventory Manager'
            ? 'Reviewed low stock produce entries.'
            : 'Reviewed crop monitoring records.',
        timestamp: now.subtract(const Duration(hours: 2)),
        module: roleName == 'Farm Inventory Manager' ? 'Stocks' : 'Crops',
      ),
      ProfileActivityModel(
        title: 'Marked Notification as Read',
        description: 'Opened a related SeedRover notification.',
        timestamp: now.subtract(const Duration(days: 1, hours: 3)),
        module: 'Notifications',
      ),
      ProfileActivityModel(
        title: 'Camera Connected',
        description: 'Checked rover camera availability.',
        timestamp: now.subtract(const Duration(days: 5)),
        module: 'Rover',
      ),
    ];
  }
}

final _mockUsers = <ProfileUserModel>[
  ProfileUserModel(
    id: 'user-001',
    employeeId: 'EMP-001',
    fullName: 'Brian A.',
    username: 'brian.admin',
    email: 'brian.admin@seedrover.local',
    contactNumber: '+63 917 100 2001',
    roleName: 'System Administrator',
    dateJoined: DateTime(2026, 1, 12),
    status: ProfileAccountStatus.active,
  ),
  ProfileUserModel(
    id: 'user-002',
    employeeId: 'EMP-014',
    fullName: 'Mika Planting',
    username: 'mika.planting',
    email: 'mika.planting@seedrover.local',
    contactNumber: '+63 917 100 2014',
    roleName: 'Farm Planting Manager',
    dateJoined: DateTime(2026, 2, 8),
    status: ProfileAccountStatus.active,
  ),
  ProfileUserModel(
    id: 'user-003',
    employeeId: 'EMP-021',
    fullName: 'Rico Inventory',
    username: 'rico.inventory',
    email: 'rico.inventory@seedrover.local',
    contactNumber: '+63 917 100 2021',
    roleName: 'Farm Inventory Manager',
    dateJoined: DateTime(2026, 2, 18),
    status: ProfileAccountStatus.active,
  ),
  ProfileUserModel(
    id: 'user-004',
    employeeId: 'EMP-033',
    fullName: 'Lara Staff',
    username: 'lara.staff',
    email: 'lara.staff@seedrover.local',
    contactNumber: '+63 917 100 2033',
    roleName: 'Farm Staff',
    dateJoined: DateTime(2026, 3, 5),
    status: ProfileAccountStatus.inactive,
  ),
  ProfileUserModel(
    id: 'user-005',
    employeeId: 'EMP-041',
    fullName: 'Paolo Field',
    username: 'paolo.field',
    email: 'paolo.field@seedrover.local',
    contactNumber: '+63 917 100 2041',
    roleName: 'Farm Staff',
    dateJoined: DateTime(2026, 4, 10),
    status: ProfileAccountStatus.suspended,
  ),
];
