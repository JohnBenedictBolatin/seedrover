import 'package:flutter_test/flutter_test.dart';
import 'package:seedrover/core/utils/app_input_formatters.dart';

void main() {
  group('contact number contract', () {
    test(
        'phone formatter accepts digits only and normalizes a pasted +63 value',
        () {
      final formatter = AppInputFormatters.phoneNumber.single;
      final formatted = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(text: '+63 917 123 4567'),
      );
      expect(formatted.text, '09171234567');
      final overlong = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(text: '0917123456789'),
      );
      expect(overlong.text, '09171234567');
      final withLetters = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(text: '0917abc4567'),
      );
      expect(withLetters.text, '09174567');
    });

    test('normalizes local and Philippine international numbers', () {
      expect(
        AppInputFormatters.normalizeContactNumber('09171234567',
            required: true),
        '09171234567',
      );
      expect(
        AppInputFormatters.normalizeContactNumber('+63 917 123 4567',
            required: true),
        '09171234567',
      );
      expect(
        AppInputFormatters.normalizeContactNumber('639171234567',
            required: true),
        '09171234567',
      );
    });

    test('rejects letters and incorrect lengths', () {
      for (final value in ['0917ABC4567', '091712345678', '0917123456']) {
        expect(
          () =>
              AppInputFormatters.normalizeContactNumber(value, required: true),
          throwsFormatException,
        );
      }
      expect(
          AppInputFormatters.validateContactNumber('0917ABC4567'), isNotNull);
    });

    test('keeps optional and legacy values distinct', () {
      expect(AppInputFormatters.normalizeContactNumber(''), isNull);
      expect(
        AppInputFormatters.normalizeContactNumber('Not provided',
            allowLegacy: true),
        'Not provided',
      );
      expect(
        () => AppInputFormatters.normalizeContactNumber('', required: true),
        throwsFormatException,
      );
    });
  });

  test('database decimal formatter limits to precision 12, scale 2', () {
    final formatter = AppInputFormatters.decimal.single;
    String apply(String value) => formatter
        .formatEditUpdate(
          const TextEditingValue(),
          TextEditingValue(text: value),
        )
        .text;

    expect(apply('12345678901.23'), '');
    expect(apply('1234567890.23'), '1234567890.23');
    expect(apply('12.345'), '');
  });
}
