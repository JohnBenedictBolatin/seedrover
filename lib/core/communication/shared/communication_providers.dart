import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bluetooth/bluetooth_communication_service.dart';
import '../wifi/wifi_communication_service.dart';
import 'communication_controller.dart';
import 'communication_enums.dart';
import 'communication_repository.dart';
import 'communication_service.dart';
import 'communication_state.dart';

final bluetoothCommunicationServiceProvider =
    Provider<BluetoothCommunicationService>(
  (ref) {
    final service = BluetoothCommunicationService();
    ref.onDispose(service.dispose);
    return service;
  },
);

final wifiCommunicationServiceProvider = Provider<WiFiCommunicationService>(
  (ref) {
    final service = WiFiCommunicationService();
    ref.onDispose(service.dispose);
    return service;
  },
);

final communicationRepositoryProvider = Provider<CommunicationRepository>(
  (ref) {
    final repository = CommunicationRepository(
      services: <CommunicationTransport, CommunicationService>{
        CommunicationTransport.bluetooth:
            ref.watch(bluetoothCommunicationServiceProvider),
        CommunicationTransport.wifi: ref.watch(wifiCommunicationServiceProvider),
      },
    );
    ref.onDispose(repository.dispose);
    return repository;
  },
);

final communicationControllerProvider =
    StateNotifierProvider<CommunicationController, CommunicationState>(
  (ref) => CommunicationController(ref.watch(communicationRepositoryProvider)),
);
