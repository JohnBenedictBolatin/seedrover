import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/config/app_environment.dart';
import '../controllers/rover_control_controller.dart';
import '../controllers/rover_control_state.dart';
import '../data/repositories/rover_repository.dart';
import '../data/services/simulated_rover_communication_service.dart';
import '../data/services/local_wifi_rover_service.dart';

final localWifiRoverServiceProvider = Provider<LocalWifiRoverService>((ref) {
  final environment = ref.watch(appEnvironmentProvider);
  final service = LocalWifiRoverService(
    baseUrl: environment.roverBaseUrl,
    roverToken: environment.roverToken,
  );
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

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
  (ref) => RoverControlController(
    ref.watch(roverRepositoryProvider),
    ref.watch(localWifiRoverServiceProvider),
  ),
);
