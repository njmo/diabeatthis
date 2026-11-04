import 'package:diabeatthis/common/history/recorded_immediate_carbohydrates.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime(2026, 10, 28, 18, 35);
  final entry = Treat(externalId: 'carbs', createdAt: at, carbs: 20);
  BolusWizard wizard({Treat? component}) => BolusWizard(
    nightscoutObjectId: 'wizard',
    createdAt: at,
    date: at,
    glucose: 100,
    units: 'mg/dl',
    notes: null,
    calculatorResult: null,
    carbohydrateRecord: component,
  );

  test(
    'calculator and embedded component do not duplicate an explicit carb entry',
    () {
      expect(
        recordedImmediateCarbohydrates([entry, wizard(component: entry)]),
        [entry],
      );
      expect(recordedImmediateCarbohydrates([wizard(component: entry)]), [
        entry,
      ]);
      expect(recordedImmediateCarbohydrates([wizard()]), isEmpty);
    },
  );

  test(
    'extended delivery stays separate; ordinary zero-duration carbs are visible',
    () {
      final records = recordedImmediateCarbohydrates([
        ExtendedCarb(
          externalId: 'ordinary',
          createdAt: at,
          carbs: 15,
          duration: 0,
        ),
        ExtendedCarb(
          externalId: 'extended',
          createdAt: at,
          carbs: 30,
          duration: 60,
        ),
        Treat(externalId: 'invalid', createdAt: at, carbs: 20, isValid: false),
      ]);
      expect(records.map((entry) => entry.carbs), [15]);
    },
  );
}
