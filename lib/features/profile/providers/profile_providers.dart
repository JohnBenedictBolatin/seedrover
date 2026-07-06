import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_providers.dart';
import '../controllers/profile_controller.dart';
import '../controllers/profile_state.dart';

final profileControllerProvider =
    StateNotifierProvider<ProfileController, ProfileState>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final authProfile = ref.watch(authControllerProvider).profile;

  return ProfileController(repository, authProfile);
});
