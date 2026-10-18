import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_providers.dart';
import '../controllers/assistant_controller.dart';
import '../controllers/assistant_state.dart';
import '../data/repositories/assistant_repository.dart';

final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AssistantState>(
  (ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final permissionKeys = profile?.permissions
            .map((permission) => permission.permissionKey)
            .toList() ??
        <String>[];
    permissionKeys.sort();
    final permissionScope = profile == null
        ? null
        : '${profile.id}:${profile.roleName}:${permissionKeys.join(',')}';
    return AssistantController(
      ref.watch(assistantRepositoryProvider),
      userId: permissionScope,
    );
  },
);
