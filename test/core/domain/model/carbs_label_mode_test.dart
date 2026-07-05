import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CarbsLabelMode', () {
    test('uses non-UE as fallback for missing storage value', () {
      expect(CarbsLabelModeX.fromStorage(null), CarbsLabelMode.nonEu);
      expect(CarbsLabelModeX.fromStorage('unknown'), CarbsLabelMode.nonEu);
    });

    test('keeps explicit non-UE storage value', () {
      expect(CarbsLabelModeX.fromStorage('non_eu'), CarbsLabelMode.nonEu);
    });
  });
}
