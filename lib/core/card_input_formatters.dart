import 'package:flutter/services.dart';

/// Masks card number as 0000 0000 0000 0000 (digits only, max 16).
class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 16) return oldValue;
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Masks expiry as MM/YY (digits only, max 4).
class ExpiryInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 4) return oldValue;
    String formatted;
    if (digits.length >= 2) {
      final month = digits.substring(0, 2);
      final m = int.tryParse(month) ?? 0;
      final clamped = m.clamp(1, 12).toString().padLeft(2, '0');
      formatted = clamped + (digits.length > 2 ? '/${digits.substring(2)}' : '/');
    } else {
      formatted = digits;
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// CVV: digits only, 3 or 4 chars.
class CvvInputFormatter extends TextInputFormatter {
  final int maxLength;

  CvvInputFormatter({this.maxLength = 4});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > maxLength) return oldValue;
    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
