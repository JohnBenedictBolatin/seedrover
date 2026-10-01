import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/shared/utils/sensor_reading_age_label.dart';

void main() {
  final now = DateTime(2026, 9, 28, 12);

  test('formats sensor reading age in minutes, hours, and days', () {
    expect(
      sensorReadingAgeLabel(now.subtract(const Duration(minutes: 47)), now: now),
      '47 minutes ago',
    );
    expect(
      sensorReadingAgeLabel(now.subtract(const Duration(hours: 2)), now: now),
      '2 hours ago',
    );
    expect(
      sensorReadingAgeLabel(now.subtract(const Duration(days: 3)), now: now),
      '3 days ago',
    );
  });

  test('uses a short label for recent or unavailable readings', () {
    expect(
      sensorReadingAgeLabel(now.subtract(const Duration(seconds: 20)), now: now),
      'Less than a minute ago',
    );
    expect(sensorReadingAgeLabel(null, now: now), 'No reading recorded');
  });
}
