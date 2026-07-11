import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/crop_monitoring_controller.dart';
import '../controllers/crop_monitoring_state.dart';
import '../data/repositories/crop_repository.dart';

final cropMonitoringControllerProvider = StateNotifierProvider<
    CropMonitoringController, CropMonitoringState>((ref) {
  final repository = ref.watch(cropRepositoryProvider);

  return CropMonitoringController(repository);
});
