import 'package:intl/intl.dart';

class CurrencyFormatter {
  const CurrencyFormatter._();

  static final _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  static final _numberFormat = NumberFormat('#,##0', 'en_US');

  static String php(num value) {
    return 'PHP ${_currencyFormat.format(value)}';
  }

  static String number(num value) {
    return _numberFormat.format(value);
  }

  static String phpOrUnset(num? value) {
    if (value == null) {
      return 'Not set';
    }

    return php(value);
  }
}
