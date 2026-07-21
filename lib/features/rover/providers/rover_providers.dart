import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../controllers/rover_control_controller.dart';
import '../controllers/rover_control_state.dart';
import '../data/repositories/rover_repository.dart';
import '../data/services/simulated_rover_communication_service.dart';

final simulatedRoverCommunicationServiceProvider =
    Provider<SimulatedRoverCommunicationService>(
  (ref) => SimulatedRoverCommunicationService(),
);

final roverRepositoryProvider = Provider<RoverRepository>(
  (ref) => RoverRepository(
    communicationService: ref.watch(simulatedRoverCommunicationServiceProvider),
    client: ref.watch(supabaseClientProvider),
  ),
);

final roverControlControllerProvider =
    StateNotifierProvider<RoverControlController, RoverControlState>(
  (ref) => RoverControlController(ref.watch(roverRepositoryProvider)),
);
