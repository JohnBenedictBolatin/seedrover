import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/core/constants/permission_keys.dart';
import 'package:seedrover/features/authentication/data/models/auth_permission_model.dart';
import 'package:seedrover/features/authentication/data/models/auth_profile_model.dart';

AuthProfileModel profileFor(
  String roleName, {
  List<AuthPermissionModel> permissions = const [],
}) => AuthProfileModel(
      id: 'profile-id',
      username: 'staff',
      email: 'staff@example.com',
      fullName: 'Staff User',
      roleName: roleName,
      isActive: true,
      permissions: permissions,
    );

void main() {
  test('Planting Staff inherits Planting Manager operational permissions', () {
    final staff = profileFor('Planting Staff');
    final manager = profileFor('Farm Planting Manager');

    for (final permission in [
      PermissionKeys.roverView,
      PermissionKeys.roverControl,
      PermissionKeys.roverCameraView,
      PermissionKeys.roverPlantingControl,
      PermissionKeys.cropsView,
      PermissionKeys.cropsManage,
      PermissionKeys.notificationsView,
    ]) {
      expect(
          staff.hasPermission(permission), manager.hasPermission(permission));
    }
    expect(staff.hasPermission(PermissionKeys.dashboardView), isFalse);
    expect(manager.hasPermission(PermissionKeys.dashboardView), isFalse);
    expect(
      profileFor(
        'Planting Staff',
        permissions: const [
          AuthPermissionModel(
            id: 'dashboard',
            permissionKey: PermissionKeys.dashboardView,
            module: 'Dashboard',
          ),
        ],
      ).hasPermission(PermissionKeys.dashboardView),
      isFalse,
    );
    expect(staff.hasPermission(PermissionKeys.stocksManage), isFalse);
  });

  test('Inventory Staff inherits Inventory Manager operational permissions',
      () {
    final staff = profileFor('Inventory Staff');
    final manager = profileFor('Farm Inventory Manager');

    for (final permission in [
      PermissionKeys.stocksView,
      PermissionKeys.stocksManage,
      PermissionKeys.stocksTransactionsView,
      PermissionKeys.stocksSalesRecord,
      PermissionKeys.stocksPricingManage,
      PermissionKeys.notificationsView,
    ]) {
      expect(
          staff.hasPermission(permission), manager.hasPermission(permission));
    }
    expect(manager.hasPermission(PermissionKeys.dashboardView), isTrue);
    expect(staff.hasPermission(PermissionKeys.dashboardView), isFalse);
    expect(
      profileFor(
        'Inventory Staff',
        permissions: const [
          AuthPermissionModel(
            id: 'dashboard',
            permissionKey: PermissionKeys.dashboardView,
            module: 'Dashboard',
          ),
        ],
      ).hasPermission(PermissionKeys.dashboardView),
      isFalse,
    );
    expect(staff.hasPermission(PermissionKeys.cropsManage), isFalse);
  });
}
