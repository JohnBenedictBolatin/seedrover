/// Calendar boundaries for SeedRover reports in Philippine time.
/// Returned DateTimes represent instants and can be compared to UTC timestamps.
abstract final class BusinessCalendar {
  static const timeZoneOffset = Duration(hours: 8);

  static DateTime now() => DateTime.now().toUtc();

  static DateTime _calendarNow(DateTime? instant) =>
      (instant ?? now()).toUtc().add(timeZoneOffset);

  static DateTime _atManilaMidnight(int year, int month, int day) =>
      DateTime.utc(year, month, day, -timeZoneOffset.inHours);

  static DateTime startOfDay([DateTime? instant]) {
    final date = _calendarNow(instant);
    return _atManilaMidnight(date.year, date.month, date.day);
  }

  static DateTime startOfWeek([DateTime? instant]) {
    final date = _calendarNow(instant);
    final daysAfterMonday =
        (DateTime.utc(date.year, date.month, date.day).weekday - 1);
    final monday =
        DateTime.utc(date.year, date.month, date.day - daysAfterMonday);
    return _atManilaMidnight(monday.year, monday.month, monday.day);
  }

  static DateTime startOfMonth([DateTime? instant]) {
    final date = _calendarNow(instant);
    return _atManilaMidnight(date.year, date.month, 1);
  }

  static DateTime startOfYear([DateTime? instant]) {
    final date = _calendarNow(instant);
    return _atManilaMidnight(date.year, 1, 1);
  }

  static DateTime startOfNextMonth([DateTime? instant]) {
    final date = _calendarNow(instant);
    return _atManilaMidnight(date.year, date.month + 1, 1);
  }

  static DateTime startOfNextYear([DateTime? instant]) {
    final date = _calendarNow(instant);
    return _atManilaMidnight(date.year + 1, 1, 1);
  }
}
