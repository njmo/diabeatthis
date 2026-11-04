import 'package:diabeatthis/common/nutrition/weighted_confidence.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('large ingredients have proportionally more influence', () {
    expect(
      weightedConfidence([
        (weight: 800.0, confidence: 0.9),
        (weight: 100.0, confidence: 0.2),
        (weight: 50.0, confidence: 0.2),
        (weight: 50.0, confidence: 0.2),
      ]),
      closeTo(0.76, 0.00001),
    );
  });
  test('splitting an ingredient does not change confidence', () {
    expect(
      weightedConfidence([
        (weight: 80.0, confidence: 0.9),
        (weight: 20.0, confidence: 0.5),
      ]),
      weightedConfidence([
        (weight: 40.0, confidence: 0.9),
        (weight: 40.0, confidence: 0.9),
        (weight: 20.0, confidence: 0.5),
      ]),
    );
  });
  test('unknown positive contributions and empty meals have no estimate', () {
    expect(weightedConfidence([(weight: 10.0, confidence: null)]), isNull);
    expect(weightedConfidence([]), isNull);
    expect(weightedConfidence([(weight: 0.0, confidence: 0.5)]), isNull);
  });
}
