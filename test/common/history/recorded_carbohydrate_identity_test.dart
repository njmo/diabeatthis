import 'package:diabeatthis/common/history/recorded_immediate_carbohydrates.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'same-time independent records survive while shared IDs are deduplicated',
    () {
      final at = DateTime(2026);
      final first = Treat(externalId: 'first', createdAt: at, carbs: 15);
      final second = Treat(externalId: 'second', createdAt: at, carbs: 20);
      BolusWizard wizard(Treat entry) => BolusWizard(
        nightscoutObjectId: 'wizard-${entry.externalId}',
        createdAt: at,
        date: at,
        glucose: 100,
        units: 'mg/dl',
        notes: null,
        calculatorResult: null,
        carbohydrateRecord: entry,
      );
      expect(
        recordedImmediateCarbohydrates([
          first,
          wizard(first),
          wizard(second),
        ]).map((entry) => entry.carbs),
        [15, 20],
      );
    },
  );
}
