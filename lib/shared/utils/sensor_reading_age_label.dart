String sensorReadingAgeLabel(DateTime? recordedAt, {DateTime? now}) {
  if (recordedAt == null) return 'No reading recorded';
  final age = (now ?? DateTime.now()).difference(recordedAt);
  if (age.isNegative || age < const Duration(minutes: 1)) {
    return 'Less than a minute ago';
  }
  if (age < const Duration(hours: 1)) {
    final minutes = age.inMinutes;
    return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
  }
  if (age < const Duration(days: 1)) {
    final hours = age.inHours;
    return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
  }
  final days = age.inDays;
  return '$days ${days == 1 ? 'day' : 'days'} ago';
}
