import 'package:flutter/services.dart';

/// Formats a Tunisian plate while typing: "123tun4567" or "1234567"
/// becomes "123 TUN 4567" (upper case, single spaces between groups).
class TunisianPlateFormatter extends TextInputFormatter {
  static String format(String input) {
    var raw = input.toUpperCase().replaceAll(RegExp(r'[^0-9A-Z]'), '');
    // Only digits typed and more than 3: insert "TUN" after the series.
    if (RegExp(r'^\d{4,}$').hasMatch(raw)) {
      raw = '${raw.substring(0, 3)}TUN${raw.substring(3)}';
    }
    final parts = RegExp(r'\d+|[A-Z]+')
        .allMatches(raw)
        .map((m) => m.group(0)!)
        .take(3)
        .toList();
    // Series max 3 digits, number max 4 digits.
    if (parts.isNotEmpty && RegExp(r'^\d+$').hasMatch(parts[0]) &&
        parts[0].length > 3) {
      parts[0] = parts[0].substring(0, 3);
    }
    if (parts.length == 3 && parts[2].length > 4) {
      parts[2] = parts[2].substring(0, 4);
    }
    return parts.join(' ');
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = format(newValue.text);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
