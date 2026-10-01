import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/core/utils/business_calendar.dart';

void main() {
  group('BusinessCalendar uses Asia/Manila calendar boundaries', () {
    test('day boundary is independent of the device timezone', () {
      final beforeManilaMidnight = DateTime.utc(2026, 3, 2, 15, 59);
      final afterManilaMidnight = DateTime.utc(2026, 3, 2, 16);

      expect(
        BusinessCalendar.startOfDay(beforeManilaMidnight),
        DateTime.utc(2026, 3, 1, 16),
      );
      expect(
        BusinessCalendar.startOfDay(afterManilaMidnight),
        DateTime.utc(2026, 3, 2, 16),
      );
    });

    test('week starts Monday in Manila time', () {
      final mondayAtMidnight = DateTime.utc(2026, 3, 1, 16);
      final sundayInManila = DateTime.utc(2026, 3, 8, 15, 59);

      expect(
        BusinessCalendar.startOfWeek(mondayAtMidnight),
        DateTime.utc(2026, 3, 1, 16),
      );
      expect(
        BusinessCalendar.startOfWeek(sundayInManila),
        DateTime.utc(2026, 3, 1, 16),
      );
    });

    test('month, year, and leap-day boundaries are calendar based', () {
      final leapDay = DateTime.utc(2024, 2, 29, 4);

      expect(BusinessCalendar.startOfMonth(leapDay),
          DateTime.utc(2024, 1, 31, 16));
      expect(BusinessCalendar.startOfYear(leapDay),
          DateTime.utc(2023, 12, 31, 16));
      expect(BusinessCalendar.startOfNextMonth(leapDay),
          DateTime.utc(2024, 2, 29, 16));
      expect(BusinessCalendar.startOfNextYear(leapDay),
          DateTime.utc(2024, 12, 31, 16));
    });
  });
}
