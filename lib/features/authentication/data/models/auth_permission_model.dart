class AuthPermissionModel {
  const AuthPermissionModel({
    required this.id,
    required this.permissionKey,
    required this.module,
    this.description,
  });

  factory AuthPermissionModel.fromJson(Map<String, dynamic> json) {
    return AuthPermissionModel(
      id: json['id'] as String,
      permissionKey: json['permission_key'] as String,
      module: json['module'] as String,
      description: json['description'] as String?,
    );
  }

  final String id;
  final String permissionKey;
  final String module;
  final String? description;
}
