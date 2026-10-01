import 'package:flutter/services.dart';

import '../constants/shared_workflow_terms.dart';

abstract final class AppInputFormatters {
  static final decimal = <TextInputFormatter>[
    TextInputFormatter.withFunction((oldValue, newValue) {
      return RegExp(r'^\d{0,10}(?:\.\d{0,2})?$').hasMatch(newValue.text)
          ? newValue
          : oldValue;
    }),
  ];

  static final phoneNumber = <TextInputFormatter>[
    _PhilippineContactFormatter(),
  ];

  static final wholeNumber = <TextInputFormatter>[
    FilteringTextInputFormatter.digitsOnly,
    LengthLimitingTextInputFormatter(10),
  ];

  static String? normalizeContactNumber(
    String? value, {
    bool required = false,
    bool allowLegacy = false,
  }) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      if (required) {
        throw const FormatException('Enter an 11-digit contact number.');
      }
      return null;
    }
    if (allowLegacy && raw.toLowerCase() == 'not provided') {
      return 'Not provided';
    }
    if (!RegExp(r'^\+?[0-9\s().-]+$').hasMatch(raw)) {
      throw const FormatException(
          'Contact number must contain exactly 11 digits.');
    }

    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final isInternational = (raw.startsWith('+63') ||
            (!raw.startsWith('+') && digits.startsWith('63'))) &&
        digits.length == 12;
    if (isInternational) return '0${digits.substring(2)}';

    if (RegExp(SharedWorkflowRules.contactNumberPattern).hasMatch(digits)) {
      return digits;
    }
    throw const FormatException(
        'Contact number must contain exactly 11 digits.');
  }

  static String? validateContactNumber(
    String? value, {
    bool required = false,
  }) {
    try {
      normalizeContactNumber(value, required: required);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }
}

class _PhilippineContactFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text.trim();
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final international = (raw.startsWith('+63') || digits.startsWith('63')) &&
        digits.length == 12;
    final normalized = international
        ? '0${digits.substring(2)}'
        : digits.substring(
            0,
            digits.length > SharedWorkflowRules.contactNumberDigits
                ? SharedWorkflowRules.contactNumberDigits
                : digits.length,
          );
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
      composing: TextRange.empty,
    );
  }
}
