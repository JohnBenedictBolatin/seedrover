import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/assistant_controller.dart';
import '../controllers/assistant_state.dart';
import '../data/repositories/assistant_context_repository.dart';
import '../data/repositories/assistant_repository.dart';

final assistantControllerProvider =
    StateNotifierProvider<AssistantController, AssistantState>(
  (ref) => AssistantController(
    ref.watch(assistantRepositoryProvider),
    readContext: () => ref.read(assistantContextProvider),
  ),
);
