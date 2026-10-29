import 'package:diabeatthis/common/analysis/dml_prediction_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'same facts share a reference but different curves at the same instant do not',
    () {
      final registry = DmlPredictionRegistry();
      final a = registry.register({
        'at': '2026-10-29T12:00Z',
        'series': {
          'IOB': [120, 130],
          'COB': [120, 140],
        },
      });
      final b = registry.register({
        'series': {
          'COB': [120, 140],
          'IOB': [120, 130],
        },
        'at': '2026-10-29T12:00Z',
      });
      final c = registry.register({
        'at': '2026-10-29T12:00Z',
        'series': {
          'IOB': [120, 200],
          'COB': [120, 140],
        },
      });
      expect(a, b);
      expect(a, isNot(c));
      expect(registry.entries, hasLength(2));
    },
  );
  test(
    'later source mutation does not alter the registered forecast or chronological samples',
    () {
      final curve = [120, 100, 140];
      final registry = DmlPredictionRegistry();
      registry.register({
        'series': {'IOB': curve},
      });
      curve[1] = 999;
      expect((registry.entries.single.facts['series'] as Map)['IOB'], [
        120,
        100,
        140,
      ]);
    },
  );
}
