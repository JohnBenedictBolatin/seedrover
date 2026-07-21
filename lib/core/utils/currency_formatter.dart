class CurrencyFormatter {
  const CurrencyFormatter._();

  static String php(num value) {
    return 'PHP ${value.toStringAsFixed(2)}';
  }

  static String phpOrUnset(num? value) {
    if (value == null) {
      return 'Not set';
    }

    return php(value);
  }
}
