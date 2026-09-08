import 'package:flutter/material.dart';

import '../../core/domain/model/stress_event_treatment.dart';
import '../../core/domain/model/stress_level.dart';
import '../../core/domain/model/treatment_base.dart';
import '../history/history_event_presentation.dart';
import '../history/history_event_type.dart';
import '../history/stress_event_labels.dart';
import '../l10n/language.dart';
import 'timeline_analysis_charts.dart';

List<TimelineChartRange> stressEventChartRanges({
  required Iterable<Treatment> treatments,
  required DateTime start,
  required DateTime end,
  required AppLocalizations messages,
}) => treatments
    .whereType<StressEventTreatment>()
    .where((treatment) {
      final event = treatment.event;
      return event.endedAt != null &&
          event.occurredAt.isBefore(end) &&
          event.endedAt!.isAfter(start);
    })
    .map((treatment) {
      final event = treatment.event;
      final color = switch (event.stressLevel) {
        StressLevel.low => Colors.amber,
        StressLevel.high => Colors.deepOrange,
        _ => Colors.orange,
      };
      return TimelineChartRange(
        start: event.occurredAt.isBefore(start) ? start : event.occurredAt,
        end: event.endedAt!.isAfter(end) ? end : event.endedAt!,
        color: color,
        alpha: 0.12,
        label:
            '${historyEventLabel(messages, HistoryEventType.stress)} · ${stressLevelLabel(messages, event.stressLevel)}',
        startIcon: historyEventIcon(HistoryEventType.stress),
        endIcon: Icons.done,
        startLabel: messages.manualEventStressStart,
        endLabel: messages.manualEventStressEnd,
      );
    })
    .toList();
