import 'package:diabeatthis/features/day_analysis/presentation/formatters/day_stat_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('day statistics share decimal separators for each supported locale', () {
    const pl = DayStatFormatter('pl');
    const en = DayStatFormatter('en');
    expect(pl.insulin(7.5), '7,50 U');
    expect(en.insulin(7.5), '7.50 U');
    expect(pl.grams(3.5), '3,5 g');
    expect(en.grams(3.5), '3.5 g');
    expect(pl.percent(50.5, decimals: 1), '50,5%');
    expect(en.percent(50.5, decimals: 1), '50.5%');
    expect(pl.number(4, decimals: 0), '4');
  });
  test('unknown and invalid numbers remain distinct from recorded zero', () {
    const format = DayStatFormatter('pl');
    for (final value in [null, double.nan, double.infinity]) {
      expect(format.insulin(value), '—');
      expect(format.percent(value), '—');
    }
    expect(format.insulin(0), '0,00 U');
    expect(format.percent(0), '0%');
  });
}
