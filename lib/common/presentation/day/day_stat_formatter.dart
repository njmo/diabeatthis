import 'package:intl/intl.dart';

/// Locale-aware numeric labels shared by live and archived day cards.
class DayStatFormatter {
  final String locale;
  const DayStatFormatter(this.locale);

  String number(num? value, {int decimals = 1, String unit = ''}) {
    if (value == null || !value.isFinite) return '—';
    final pattern = decimals == 0 ? '0' : '0.${'0' * decimals}';
    final formatted = NumberFormat(pattern, locale).format(value);
    return unit.isEmpty ? formatted : '$formatted$unit';
  }

  String insulin(num? value) => number(value, decimals: 2, unit: ' U');
  String grams(num? value) => number(value, unit: ' g');
  String percent(num? value, {int decimals = 0}) =>
      number(value, decimals: decimals, unit: '%');
}
