import 'package:flutter/material.dart';

import '../../core/domain/model/correction_bolus.dart';
import '../../core/domain/model/extended_carb.dart';
import '../../core/domain/model/manual_bolus.dart';
import '../../core/domain/model/meal.dart';
import '../../core/domain/model/stress_event_treatment.dart';
import '../../core/domain/model/temporary_target.dart';
import '../../core/domain/model/treat.dart';
import '../../core/domain/model/treatment_base.dart';
import '../l10n/language.dart';
import 'history_event_presentation.dart';
import 'history_event_type.dart';

typedef TreatmentPresentation = ({String label, IconData icon, Color color});

TreatmentPresentation treatmentPresentation(
  AppLocalizations messages,
  Treatment treatment,
) {
  final type = switch (treatment) {
    StressEventTreatment() => HistoryEventType.stress,
    Meal() => HistoryEventType.nightscoutMeal,
    TemporaryTarget() => HistoryEventType.tempTarget,
    Treat() || ExtendedCarb() => HistoryEventType.carbs,
    ManualBolus() => HistoryEventType.manualCorrection,
    CorrectionBolus() => HistoryEventType.correction,
    _ => null,
  };
  return (
    label: treatment is ExtendedCarb
        ? messages.historyExtendedCarbs
        : type == null
        ? messages.activityTreatmentEvent
        : historyEventLabel(messages, type),
    icon: type == null ? treatment.getIcon() : historyEventIcon(type),
    color: type == null ? treatment.getColor() : historyEventColor(type),
  );
}
