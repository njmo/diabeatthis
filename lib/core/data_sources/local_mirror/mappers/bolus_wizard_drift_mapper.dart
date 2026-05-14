import 'package:drift/drift.dart';

import '../../../domain/model/bolus_calculator_result.dart' as domain;
import '../../../domain/model/bolus_wizard.dart' as domain;
import '../../../drift/database_impl.dart' as drift;
import '../../config/data_source_config.dart';

extension BolusWizardDriftMapper on domain.BolusWizard {
  drift.BolusWizardCompanion toCompanion(EventSource source) {
    final calculator = calculatorResult;

    return drift.BolusWizardCompanion.insert(
      source: source.storageValue,
      externalId: source == EventSource.cloud && nightscoutObjectId != null
          ? Value(nightscoutObjectId!)
          : const Value.absent(),
      createdAt: Value(createdAt.millisecondsSinceEpoch),
      nightscoutId: Value(nightscoutObjectId),
      glucose: Value(glucose),
      units: Value(units),
      carbs: Value(calculator?.carbs),
      insulin: Value(calculator?.totalInsulin),
      basalIob: Value(calculator?.basalIob),
      bolusIob: Value(calculator?.bolusIob),
      carbsInsulin: Value(calculator?.carbsInsulin),
      cob: Value(calculator?.cob),
      cobInsulin: Value(calculator?.cobInsulin),
      calculatorCreatedAt: Value(
        calculator?.dateCreated?.millisecondsSinceEpoch,
      ),
      glucoseDifference: Value(calculator?.glucoseDifference),
      glucoseInsulin: Value(calculator?.glucoseInsulin),
      glucoseTrend: Value(calculator?.glucoseTrend),
      glucoseValue: Value(calculator?.glucoseValue),
      ic: Value(calculator?.ic),
      calculatorId: Value(calculator?.id),
      isf: Value(calculator?.isf),
      calculatorNote: Value(calculator?.note),
      otherCorrection: Value(calculator?.otherCorrection),
      percentageCorrection: Value(calculator?.percentageCorrection),
      profileName: Value(calculator?.profileName),
      superbolusInsulin: Value(calculator?.superbolusInsulin),
      targetBgHigh: Value(calculator?.targetBGHigh),
      targetBgLow: Value(calculator?.targetBGLow),
      calculatorTimestamp: Value(calculator?.timestamp?.millisecondsSinceEpoch),
      trendInsulin: Value(calculator?.trendInsulin),
      utcOffset: Value(calculator?.utcOffset),
      calculatorVersion: Value(calculator?.version),
      wasBasalIobUsed: Value(calculator?.wasBasalIOBUsed),
      wasBolusIobUsed: Value(calculator?.wasBolusIOBUsed),
      wasCobUsed: Value(calculator?.wasCOBUsed),
      wasGlucoseUsed: Value(calculator?.wasGlucoseUsed),
      wasSuperbolusUsed: Value(calculator?.wasSuperbolusUsed),
      wasTempTargetUsed: Value(calculator?.wasTempTargetUsed),
      wasTrendUsed: Value(calculator?.wasTrendUsed),
      wereCarbsUsed: Value(calculator?.wereCarbsUsed),
      notes: Value(notes),
    );
  }
}

extension BolusWizardDomainMapper on drift.BolusWizardData {
  domain.BolusWizard toDomain() {
    return domain.BolusWizard(
      nightscoutObjectId: nightscoutId,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      date: DateTime.fromMillisecondsSinceEpoch(createdAt),
      glucose: glucose ?? 0,
      units: units,
      notes: notes,
      calculatorResult: domain.BolusCalculatorResult(
        basalIob: basalIob,
        bolusIob: bolusIob,
        carbs: carbs,
        carbsInsulin: carbsInsulin,
        cob: cob,
        cobInsulin: cobInsulin,
        dateCreated: _dateTimeFromMilliseconds(calculatorCreatedAt),
        glucoseDifference: glucoseDifference,
        glucoseInsulin: glucoseInsulin,
        glucoseTrend: glucoseTrend,
        glucoseValue: glucoseValue,
        ic: ic,
        id: calculatorId,
        isf: isf,
        note: calculatorNote,
        otherCorrection: otherCorrection,
        percentageCorrection: percentageCorrection,
        profileName: profileName,
        superbolusInsulin: superbolusInsulin,
        targetBGHigh: targetBgHigh,
        targetBGLow: targetBgLow,
        timestamp: _dateTimeFromMilliseconds(calculatorTimestamp),
        totalInsulin: insulin,
        trendInsulin: trendInsulin,
        utcOffset: utcOffset,
        version: calculatorVersion,
        wasBasalIOBUsed: wasBasalIobUsed,
        wasBolusIOBUsed: wasBolusIobUsed,
        wasCOBUsed: wasCobUsed,
        wasGlucoseUsed: wasGlucoseUsed,
        wasSuperbolusUsed: wasSuperbolusUsed,
        wasTempTargetUsed: wasTempTargetUsed,
        wasTrendUsed: wasTrendUsed,
        wereCarbsUsed: wereCarbsUsed,
      ),
    );
  }
}

DateTime? _dateTimeFromMilliseconds(int? milliseconds) {
  if (milliseconds == null) return null;

  return DateTime.fromMillisecondsSinceEpoch(milliseconds);
}
