import 'package:diabeatthis/common/nutrition/confidence_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps persisted confidence values and their slider levels', () {
    final values = {
      ConfidenceLevel.low: 0.25,
      ConfidenceLevel.medium: 0.50,
      ConfidenceLevel.high: 0.75,
      ConfidenceLevel.certain: 0.95,
    };
    for (final entry in values.entries) {
      expect(entry.key.toDouble01(), entry.value);
      expect(ConfidenceLevelX.fromDouble01(entry.value), entry.key);
    }
  });

  for (final boundary in [
    (value: 0.375, below: ConfidenceLevel.low, at: ConfidenceLevel.medium),
    (value: 0.625, below: ConfidenceLevel.medium, at: ConfidenceLevel.high),
    (value: 0.85, below: ConfidenceLevel.high, at: ConfidenceLevel.certain),
  ]) {
    test('preserves confidence threshold ${boundary.value}', () {
      expect(
        ConfidenceLevelX.fromDouble01(boundary.value - 0.000001),
        boundary.below,
      );
      expect(ConfidenceLevelX.fromDouble01(boundary.value), boundary.at);
      expect(
        ConfidenceLevelX.fromDouble01(boundary.value + 0.000001),
        boundary.at,
      );
    });
  }

  test('clamps confidence values outside the persisted range', () {
    expect(ConfidenceLevelX.fromDouble01(-1), ConfidenceLevel.low);
    expect(ConfidenceLevelX.fromDouble01(0), ConfidenceLevel.low);
    expect(ConfidenceLevelX.fromDouble01(1), ConfidenceLevel.certain);
    expect(ConfidenceLevelX.fromDouble01(2), ConfidenceLevel.certain);
  });

  test('preserves slider ordering and clamps indices', () {
    final levels = [
      ConfidenceLevel.low,
      ConfidenceLevel.medium,
      ConfidenceLevel.high,
      ConfidenceLevel.certain,
    ];
    for (var index = 0; index < levels.length; index++) {
      expect(levels[index].toIndex(), index);
      expect(ConfidenceLevelX.fromIndex(index), levels[index]);
    }
    expect(ConfidenceLevelX.fromIndex(-1), ConfidenceLevel.low);
    expect(ConfidenceLevelX.fromIndex(4), ConfidenceLevel.certain);
  });
}
