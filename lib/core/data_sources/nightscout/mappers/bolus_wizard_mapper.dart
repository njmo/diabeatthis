import '../../../domain/model/bolus_calculator_result.dart';
import '../../../domain/model/bolus_wizard.dart';
import '../dto/bolus_wizard_dto.dart';

extension BolusWizardMapper on BolusWizardDto {
  BolusWizard toDomain() {
    final calculatorResult = bolusCalculatorResult?.toBolusCalculatorResult();

    return BolusWizard(
      createdAt: DateTime.parse(createdAt).toLocal(),
      date: _dateTimeFromMilliseconds(date),
      nightscoutObjectId: id,
      glucose: glucose,
      units: units,
      notes: notes,
      calculatorResult: calculatorResult,
    );
  }
}

extension _BolusCalculatorResultMapper on Map<String, dynamic> {
  BolusCalculatorResult toBolusCalculatorResult() {
    return BolusCalculatorResult(
      basalIob: _double('basalIOB'),
      bolusIob: _double('bolusIOB'),
      carbs: _double('carbs'),
      carbsInsulin: _double('carbsInsulin'),
      cob: _double('cob'),
      cobInsulin: _double('cobInsulin'),
      dateCreated: _dateTimeFromMilliseconds(_int('dateCreated')),
      glucoseDifference: _double('glucoseDifference'),
      glucoseInsulin: _double('glucoseInsulin'),
      glucoseTrend: _double('glucoseTrend'),
      glucoseValue: _double('glucoseValue'),
      ic: _double('ic'),
      id: _int('id'),
      isf: _double('isf'),
      note: this['note'] as String?,
      otherCorrection: _double('otherCorrection'),
      percentageCorrection: _int('percentageCorrection'),
      profileName: this['profileName'] as String?,
      superbolusInsulin: _double('superbolusInsulin'),
      targetBGHigh: _double('targetBGHigh'),
      targetBGLow: _double('targetBGLow'),
      timestamp: _dateTimeFromMilliseconds(_int('timestamp')),
      totalInsulin: _double('totalInsulin'),
      trendInsulin: _double('trendInsulin'),
      utcOffset: _int('utcOffset'),
      version: _int('version'),
      wasBasalIOBUsed: _bool('wasBasalIOBUsed'),
      wasBolusIOBUsed: _bool('wasBolusIOBUsed'),
      wasCOBUsed: _bool('wasCOBUsed'),
      wasGlucoseUsed: _bool('wasGlucoseUsed'),
      wasSuperbolusUsed: _bool('wasSuperbolusUsed'),
      wasTempTargetUsed: _bool('wasTempTargetUsed'),
      wasTrendUsed: _bool('wasTrendUsed'),
      wereCarbsUsed: _bool('wereCarbsUsed'),
    );
  }

  double? _double(String key) => (this[key] as num?)?.toDouble();

  int? _int(String key) => (this[key] as num?)?.toInt();

  bool? _bool(String key) => this[key] as bool?;
}

DateTime? _dateTimeFromMilliseconds(int? value) {
  if (value == null) return null;

  return DateTime.fromMillisecondsSinceEpoch(value).toLocal();
}
