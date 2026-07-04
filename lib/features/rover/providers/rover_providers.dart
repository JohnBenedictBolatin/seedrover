import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/rover_control_controller.dart';
import '../controllers/rover_control_state.dart';
import '../data/repositories/rover_repository.dart';
import '../data/services/simulated_rover_communication_service.dart';

final simulatedRoverCommunicationServiceProvider =
    Provider<SimulatedRoverCommunicationService>(
  (ref) => const SimulatedRoverCommunicationService(),
);

final roverRepositoryProvider = Provider<RoverRepository>(
  (ref) => RoverRepository(
    communicationService: ref.watch(simulatedRoverCommunicationServiceProvider),
  ),
);

final roverControlControllerProvider =
    StateNotifierProvider<RoverControlController, RoverControlState>(
  (ref) => RoverControlController(ref.watch(roverRepositoryProvider)),
);
