import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:seedrover/features/rover/data/models/planting_session_model.dart';
import 'package:seedrover/features/rover/data/repositories/planting_receipt_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pending calibration is available for the Rover sync queue', () async {
    SharedPreferences.setMockInitialValues({});
    final client = SupabaseClient('https://example.supabase.co', 'test-key');
    final repository = PlantingReceiptRepository(client);

    expect(await repository.loadPendingCalibration(), isNull);

    await repository.saveCalibration(const RoverCalibrationModel(
      secondsPerMeter: 2.1,
      soilDryRaw: 2100,
      soilWetRaw: 1055,
      rakeToGateCm: 8,
    ));

    final pending = await repository.loadPendingCalibration();
    expect(pending?.soilDryRaw, 2100);
    expect(pending?.soilWetRaw, 1055);
    expect(pending?.secondsPerMeter, 2.1);
    expect(pending?.rakeToGateCm, 8);
  });
}
