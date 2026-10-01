import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../authentication/providers/auth_providers.dart';
import '../controllers/assistant_controller.dart';
import '../controllers/assistant_state.dart';
import '../data/repositories/assistant_context_repository.dart';
import '../data/repositories/assistant_repository.dart';

final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AssistantState>(
  (ref) {
    final userId = ref.watch(authControllerProvider).profile?.id;
    return AssistantController(
      ref.watch(assistantRepositoryProvider),
      userId: userId,
      readContext: () => ref.read(assistantContextProvider),
    );
  },
);
