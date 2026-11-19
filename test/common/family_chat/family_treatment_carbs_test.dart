import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/common/family_chat/domain/family_treatment_carbs.dart';
import 'package:diabeatthis/common/meal/low_treatment_delivery_carbs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final cases =
      jsonDecode(
            File(
              'test/fixtures/family_treatment_rounding.json',
            ).readAsStringSync(),
          )
          as List;
  for (final entry in cases.cast<Map>()) {
    test(
      'nutrition and whole-gram delivery share the backend boundary contract: ${entry['input']}',
      () {
        final input = (entry['input'] as num).toDouble();
        final nutrition = familyTreatmentNutritionCarbs(input);
        expect(nutrition, (entry['nutrition'] as num).toDouble());
        if (entry['delivery'] == null) {
          expect(
            () => familyTreatmentRecordedCarbs(input),
            throwsArgumentError,
          );
        } else {
          expect(familyTreatmentRecordedCarbs(input), entry['delivery']);
          expect(lowTreatmentDeliveryCarbs(nutrition), entry['delivery']);
        }
      },
    );
  }
}
