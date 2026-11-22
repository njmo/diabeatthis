import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../core/data_sources/nightscout/dto/bolus_wizard_dto.dart';
import '../core/data_sources/nightscout/mappers/bolus_wizard_mapper.dart';
import '../core/domain/model/correction_bolus.dart';
import '../core/domain/model/extended_carb.dart';
import '../core/domain/model/manual_bolus.dart';
import '../core/domain/model/treat.dart';
import '../core/domain/model/treatment_base.dart';
import '../foreground/event/internal/treatment_event_dispatcher.dart';
import '../foreground/task/base/runtime_context.dart';
import 'debug_treatment_event.dart';

bool handleDebugTreatmentEvent(
  Map<String, dynamic> event,
  RuntimeContext context,
) {
  final appEvent = event['data'];
  if (!kDebugMode ||
      event['external_event'] != 'app_event' ||
      appEvent is! Map ||
      appEvent['app_event'] != DebugTreatmentEvent.type) {
    return false;
  }
  final data = appEvent['data'];
  if (data is! Map) return true;
  final kind = DebugTreatmentKind.values.asNameMap()[data['kind']];
  if (kind == null) return true;
  final request = DebugTreatmentEvent.tryParse(
    kind,
    insulin: data['insulin']?.toString(),
    carbs: data['carbs']?.toString(),
    minutes: data['minutes']?.toString(),
    startAfterMinutes: data['startAfterMinutes']?.toString(),
  );
  if (request == null) return true;

  final now = clock.now();
  final dispatcher = TreatmentEventDispatcher();
  void dispatch(Treatment treatment) => dispatcher.dispatch(
    container: context.container,
    emitEvent: context.emitEvent,
    treatment: treatment,
  );
  dispatch(_createTreatment(request, now));
  if (kind == DebugTreatmentKind.calculator && request.insulin! > 0) {
    dispatch(
      ManualBolus(
        externalId: 'debug-delivery-${now.millisecondsSinceEpoch}',
        createdAt: now.add(const Duration(milliseconds: 1)),
        insulin: request.insulin!,
      ),
    );
  }
  return true;
}

Treatment _createTreatment(DebugTreatmentEvent request, DateTime now) {
  final timestamp = now.millisecondsSinceEpoch;
  final id = 'debug-treatment-$timestamp';
  return switch (request.kind) {
    DebugTreatmentKind.manualBolus => ManualBolus(
      externalId: id,
      createdAt: now,
      insulin: request.insulin!,
    ),
    DebugTreatmentKind.correctionBolus => CorrectionBolus(
      externalId: id,
      createdAt: now,
      insulin: request.insulin!,
    ),
    DebugTreatmentKind.calculator => BolusWizardDto(
      id: id,
      createdAt: now.toIso8601String(),
      date: timestamp,
      glucose: 0,
      bolusCalculatorResult: {
        'carbs': request.carbs,
        'totalInsulin': request.insulin,
        'timestamp': timestamp,
      },
    ).toDomain(),
    DebugTreatmentKind.carbs => Treat(
      externalId: id,
      createdAt: now,
      carbs: request.carbs!,
    ),
    DebugTreatmentKind.extendedCarbs => ExtendedCarb(
      externalId: id,
      createdAt: now.add(Duration(minutes: request.startAfterMinutes)),
      carbs: request.carbs!,
      duration: Duration(minutes: request.minutes!).inMilliseconds,
    ),
  };
}
