import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_providers.dart';
import '../controllers/notification_controller.dart';
import '../controllers/notification_state.dart';
import '../data/repositories/notification_repository.dart';

final notificationControllerProvider =
    StateNotifierProvider<NotificationController, NotificationState>((ref) {
  final repository = ref.watch(notificationRepositoryProvider);
  final profile = ref.watch(authControllerProvider).profile;

  return NotificationController(repository, profile);
});
