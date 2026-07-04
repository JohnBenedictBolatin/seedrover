import 'auth_permission_model.dart';
import '../../../../core/constants/permission_keys.dart';

class AuthProfileModel {
  const AuthProfileModel({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.roleName,
    required this.isActive,
    required this.permissions,
  });

  factory AuthProfileModel.fromJson(
    Map<String, dynamic> json, {
    required List<AuthPermissionModel> permissions,
  }) {
    final role = json['roles'] as Map<String, dynamic>?;

    return AuthProfileModel(
      id: json['id'] as String,
      username: json['username'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String,
      roleName: role?['role_name'] as String? ?? 'Farm Staff',
      isActive: json['is_active'] as bool? ?? false,
      permissions: permissions,
    );
  }

  final String id;
  final String username;
  final String email;
  final String fullName;
  final String roleName;
  final bool isActive;
  final List<AuthPermissionModel> permissions;

  bool get isAdministrator => roleName == 'System Administrator';
  bool get isPlantingManager => roleName == 'Farm Planting Manager';
  bool get isInventoryManager => roleName == 'Farm Inventory Manager';
  bool get isFarmStaff => roleName == 'Farm Staff';

  bool hasPermission(String permissionKey) {
    if (isAdministrator) {
      return true;
    }

    if (_roleDefaultPermissions.contains(permissionKey)) {
      return true;
    }

    return permissions.any(
      (permission) => permission.permissionKey == permissionKey,
    );
  }

  Set<String> get _roleDefaultPermissions {
    if (isPlantingManager) {
      return {
        PermissionKeys.dashboardView,
        PermissionKeys.roverView,
        PermissionKeys.roverControl,
        PermissionKeys.roverCameraView,
        PermissionKeys.roverPlantingControl,
        PermissionKeys.cropsView,
        PermissionKeys.cropsManage,
        PermissionKeys.notificationsView,
        PermissionKeys.profileView,
        PermissionKeys.profileManageSelf,
      };
    }

    if (isInventoryManager) {
      return {
        PermissionKeys.dashboardView,
        PermissionKeys.stocksView,
        PermissionKeys.stocksManage,
        PermissionKeys.stocksTransactionsView,
        PermissionKeys.notificationsView,
        PermissionKeys.profileView,
        PermissionKeys.profileManageSelf,
      };
    }

    return {
      PermissionKeys.profileView,
      PermissionKeys.profileManageSelf,
    };
  }
}
