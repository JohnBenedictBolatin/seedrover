import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/features/rover/controllers/rover_control_state.dart';

void main() {
  test('phase-one ping state retains acknowledgement latency', () {
    const initial = RoverControlState.loading();
    final pinging = initial.copyWith(isPinging: true);
    final acknowledged =
        pinging.copyWith(isPinging: false, pingRoundTripMs: 247);

    expect(pinging.isPinging, isTrue);
    expect(acknowledged.isPinging, isFalse);
    expect(acknowledged.pingRoundTripMs, 247);
  });
}
