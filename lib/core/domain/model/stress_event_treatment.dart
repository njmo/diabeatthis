import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../common/history/history_event_presentation.dart';
import '../../../common/history/history_event_type.dart';
import '../../../common/history/stress_event_labels.dart';
import '../../../common/l10n/language.dart';
import 'stress_event.dart';
import 'treatment_base.dart';

/// Context events share the treatment timeline without becoming bolus insulin.
class StressEventTreatment extends Treatment {
  StressEventTreatment(this.event) : super(createdAt: event.occurredAt);

  final StressEvent event;

  @override
  bool get isValid => true;

  @override
  String getParts() => [
    stressLevelLabel(lang, event.stressLevel),
    if (event.endedAt != null)
      '${DateFormat('dd.MM HH:mm').format(event.occurredAt)}–${DateFormat('dd.MM HH:mm').format(event.endedAt!)}',
    if (event.notes?.isNotEmpty == true) event.notes!,
  ].join(' · ');

  @override
  IconData getIcon() => historyEventIcon(HistoryEventType.stress);

  @override
  Color getColor() => historyEventColor(HistoryEventType.stress);
}
