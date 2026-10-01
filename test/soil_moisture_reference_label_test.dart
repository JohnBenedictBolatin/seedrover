import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/shared/utils/soil_moisture_reference_label.dart';

void main() {
  test('uses short farmer-facing moisture labels', () {
    expect(soilMoistureReferenceLabel(3.6), 'Good for planting');
    expect(soilMoistureReferenceLabel(50), 'Too wet');
    expect(soilMoistureReferenceLabel(100), 'Too wet');
  });

  test('reports missing or invalid measurements as unavailable', () {
    expect(soilMoistureReferenceLabel(null), 'Unavailable');
    expect(soilMoistureReferenceLabel(double.nan), 'Unavailable');
    expect(soilMoistureReferenceLabel(101), 'Unavailable');
  });
}
