import '../../../domain/model/treatment_base.dart';
import '../dto/bolus_wizard_dto.dart';
import '../dto/correction_bolus_dto.dart';
import '../dto/extended_carb_dto.dart';
import '../dto/manual_bolus_dto.dart';
import '../dto/temporary_target_dto.dart';
import '../dto/treat_dto.dart';
import '../mappers/bg_check_mapper.dart';
import '../mappers/bolus_wizard_mapper.dart';
import '../mappers/correction_bolus_mapper.dart';
import '../mappers/extended_carb_mapper.dart';
import '../mappers/manual_bolus_mapper.dart';
import '../mappers/temporary_target_mapper.dart';
import '../mappers/treat_mapper.dart';

class TreatmentFactory {
  List<Treatment> parseTreatments(
    List<dynamic> treatments, {
    String? remoteSource,
  }) {
    final list = <Treatment>[];

    for (var i = 0; i < treatments.length; i++) {
      final t = treatments[i];

      final type = (t['eventType'] ?? '').toString().toLowerCase();
      if (type.trim() == 'bg check' && t is Map<String, dynamic>) {
        final check = parseBgCheck(t);
        if (check != null) list.add(check);
        continue;
      }
      if (type.contains('temporary target')) {
        list.add(TemporaryTargetDto.fromJson(t).toDomain());
        continue;
      }
      if (type.contains('bolus wizard')) {
        list.add(
          BolusWizardDto.fromJson(t).toDomain(remoteSource: remoteSource),
        );
        continue;
      }
      // A combined delivery contains independent insulin and carbohydrate facts.
      // Handle it before the duration-based extended-carbohydrate record shape.
      if (type.contains('meal bolus') || type.contains('carb correction')) {
        if (t['insulin'] != null) {
          list.add(ManualBolusDto.fromJson(t).toDomain());
        }
        if (t['carbs'] != null) {
          if (t['duration'] is num && (t['duration'] as num) > 0) {
            list.add(ExtendedCarbDto.fromJson(t).toDomain());
          } else {
            list.add(TreatDto.fromJson(t).toDomain());
          }
        }
        continue;
      }
      if (t is Map<String, dynamic> &&
          t['duration'] is num &&
          t['carbs'] is num) {
        list.add(ExtendedCarbDto.fromJson(t).toDomain());
        continue;
      }
      if (type.contains('correction bolus')) {
        list.add(CorrectionBolusDto.fromJson(t).toDomain());
      }
    }
    return list;
  }
}
