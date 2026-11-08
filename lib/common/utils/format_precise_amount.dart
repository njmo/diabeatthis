import 'package:intl/intl.dart';

/// Keeps the exact double representation while using the locale's decimal mark.
String formatPreciseAmount(double value, String localeName) {
  final raw = value.toString();
  final text = raw.endsWith('.0') ? raw.substring(0, raw.length - 2) : raw;
  return text.replaceAll(
    '.',
    NumberFormat.decimalPattern(localeName).symbols.DECIMAL_SEP,
  );
}
