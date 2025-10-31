import '../../domain/model/treatment_base.dart';

import '../dto/correction_bolus_dto.dart';
import '../dto/extended_carb_dto.dart';
import '../dto/manual_bolus_dto.dart';
import '../dto/meal_dto.dart';
import '../dto/treat_dto.dart';
import '../mappers/correction_bolus_mapper.dart';
import '../mappers/extended_carb_mapper.dart';
import '../mappers/manual_bolus_mapper.dart';
import '../mappers/meal_mapper.dart';
import '../mappers/treat_mapper.dart';

class TreatmentFactory {
  bool ignoreNextBolus = false;

  List<Treatment> parseTreatments(List<dynamic> treatments) {
    final list = <Treatment>[];
    for (var i = 0; i < treatments.length; i++) {
      final t = treatments[i];

      final type = (t['eventType'] ?? '').toString().toLowerCase();
      if (type.contains('bolus wizard')) {
        list.add(MealDto.fromJson(t).toDomain());
        ignoreNextBolus = true;
        continue;
      }
      if (t is Map<String, dynamic> && t.containsKey('duration')) {
        list.add(ExtendedCarbDto.fromJson(t).toDomain());
        continue;
      }
      // sms bolus
      if (type.contains('meal bolus') || type.contains('carb correction')) {
        final isBolusWizardNearby = [
          i - 1,
          i + 1,
        ].any((index) =>
        index >= 0 &&
            index < treatments.length &&
            treatments[index]['eventType'] == 'Bolus Wizard');

        if (isBolusWizardNearby) continue;

        if (t['carbs'] == null) {
          list.add(ManualBolusDto.fromJson(t).toDomain());
          continue;
        }
        if (t['insulin'] == null) {
          list.add(TreatDto.fromJson(t).toDomain());
          continue;
        }
      }
      if (type.contains('carb correction')) list.add(TreatDto.fromJson(t).toDomain());
      if (type.contains('correction bolus')) {
        list.add(CorrectionBolusDto.fromJson(t).toDomain());
      }
    }
    return list;
  }
}