import 'package:diabeatthis/core/data_sources/nightscout/dto/bolus_wizard_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/bolus_wizard_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps Nightscout Bolus Wizard calculator details', () {
    final dto = BolusWizardDto.fromJson({
      '_id': '6a0582bbb868b8fcf0a10f0f',
      'eventType': 'Bolus Wizard',
      'created_at': '2026-05-14T08:07:23.461Z',
      'bolusCalculatorResult':
          '{"basalIOB":-0.423,"bolusIOB":0.303,"carbs":10.0,'
          '"carbsInsulin":0.8333333333333334,"cob":0.0,'
          '"cobInsulin":0.0,"dateCreated":1778746043475,'
          '"glucoseDifference":-71.0,"glucoseInsulin":-0.39444444444444443,'
          '"glucoseTrend":-16.11,"glucoseValue":69.0,"ic":12.0,'
          '"id":1296,"isf":180.0,"note":"",'
          '"otherCorrection":0.0,"percentageCorrection":100,'
          '"profileName":"omnipod","superbolusInsulin":0.0,'
          '"targetBGHigh":140.0,"targetBGLow":140.0,'
          '"timestamp":1778746043461,"totalInsulin":0.3,'
          '"trendInsulin":-0.2685,"utcOffset":7200000,"version":0,'
          '"wasBasalIOBUsed":true,"wasBolusIOBUsed":true,'
          '"wasCOBUsed":true,"wasGlucoseUsed":true,'
          '"wasSuperbolusUsed":false,"wasTempTargetUsed":true,'
          '"wasTrendUsed":true,"wereCarbsUsed":false}',
      'date': 1778746043461,
      'glucose': 69,
      'units': 'mg/dl',
      'notes': '',
      'mills': 1778746043461,
      'carbs': null,
      'insulin': null,
    });

    final bolusWizard = dto.toDomain();
    final calculatorResult = bolusWizard.calculatorResult;

    expect(bolusWizard.nightscoutObjectId, '6a0582bbb868b8fcf0a10f0f');
    expect(bolusWizard.glucose, 69);
    expect(bolusWizard.units, 'mg/dl');
    expect(bolusWizard.carbs, 10);
    expect(bolusWizard.insulin, 0.3);
    expect(calculatorResult?.basalIob, -0.423);
    expect(calculatorResult?.bolusIob, 0.303);
    expect(calculatorResult?.glucoseTrend, -16.11);
    expect(calculatorResult?.trendInsulin, -0.2685);
    expect(calculatorResult?.profileName, 'omnipod');
    expect(calculatorResult?.wasTrendUsed, isTrue);
    expect(calculatorResult?.wereCarbsUsed, isFalse);
  });
}
