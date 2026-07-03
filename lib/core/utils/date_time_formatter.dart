import 'package:intl/intl.dart';

class DateTimeFormatter {
  const DateTimeFormatter._();

  static String formatDate(DateTime value) {
    return DateFormat.yMMMd().format(value);
  }

  static String formatTime(DateTime value) {
    return DateFormat.jm().format(value);
  }
}
