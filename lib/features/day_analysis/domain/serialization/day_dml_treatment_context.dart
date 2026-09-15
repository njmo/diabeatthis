import '../../../../core/domain/model/bg_check.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/stress_event_treatment.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../models/day_analysis_history.dart';
import 'day_dml_time_blocks.dart';

typedef DayDmlContextSection = ({
  String kind,
  String id,
  Map<String, Object?> facts,
});

/// Additional recorded context, kept separate from insulin delivery and CGM.
List<DayDmlContextSection> dayDmlTreatmentContext(
  DayAnalysisHistory history,
  DateTime start,
) {
  final end = history.end;
  bool point(DateTime at) => !at.isBefore(start) && !at.isAfter(end);
  bool overlaps(DateTime at, DateTime? until) =>
      point(at) ||
      (at.isBefore(start) && until != null && until.isAfter(start));
  final treatments = history.treatments?.where((t) => t.isValid).toList();
  final checks =
      <
        ({DateTime at, int value, GlucoseType type, GlucoseSource source}),
        ({Glucose reading, Set<String> notes})
      >{};
  for (final reading in [
    ...?history.glucose,
    for (final check in treatments?.whereType<BgCheck>() ?? <BgCheck>[])
      check.reading,
  ]) {
    if (reading.type == GlucoseType.cgm ||
        reading.sgv <= 0 ||
        !point(reading.date)) {
      continue;
    }
    final key = (
      at: reading.date.toUtc(),
      value: reading.sgv,
      type: reading.type,
      source: reading.source,
    );
    final previous = checks[key];
    final note = reading.notes?.trim();
    checks[key] = (
      reading: previous?.reading ?? reading,
      notes: {...?previous?.notes, if (note != null && note.isNotEmpty) note},
    );
  }
  bool hasTargetRange(TemporaryTarget target) =>
      target.targetBottom > 0 && target.targetTop >= target.targetBottom;
  return [
    (
      kind: 'STRESS_EVENTS',
      id: 'stress_events',
      facts: {
        'columns': ['start', 'end', 'level', 'source', 'notes'],
        'blocks': dayDmlTimeBlocks(
          treatments == null
              ? null
              : [
                  for (final treatment
                      in treatments.whereType<StressEventTreatment>())
                    if (overlaps(
                      treatment.event.occurredAt,
                      treatment.event.endedAt,
                    ))
                      (
                        at: treatment.event.occurredAt,
                        values: [
                          treatment.event.endedAt,
                          treatment.event.stressLevel.name,
                          treatment.event.source,
                          treatment.event.notes,
                        ],
                      ),
                ],
        ),
      },
    ),
    (
      kind: 'TEMP_TARGETS',
      id: 'temp_targets',
      facts: {
        'columns': [
          'start',
          'requested_duration_min',
          'low_mg_dl',
          'high_mg_dl',
        ],
        'blocks': dayDmlTimeBlocks(
          treatments == null
              ? null
              : [
                  for (final target in treatments.whereType<TemporaryTarget>())
                    // Keep the fetched lead-in, including cancellations before
                    // seriesStart; otherwise an older target could appear active.
                    if (target.duration >= 0 &&
                        !target.createdAt.isBefore(history.start) &&
                        !target.createdAt.isAfter(end))
                      (
                        at: target.createdAt,
                        values: [
                          target.duration,
                          target.duration == 0
                              ? 0
                              : hasTargetRange(target)
                              ? target.targetBottom
                              : null,
                          target.duration == 0
                              ? 0
                              : hasTargetRange(target)
                              ? target.targetTop
                              : null,
                        ],
                      ),
                ],
        ),
      },
    ),
    (
      kind: 'BG_CHECKS',
      id: 'bg_checks',
      facts: {
        'columns': ['time', 'mg_dl', 'type', 'source', 'notes'],
        'failed_sources': [
          if (history.glucose == null) 'cgm',
          if (history.treatments == null) 'treatments',
        ],
        'blocks': dayDmlTimeBlocks(
          history.glucose == null && treatments == null
              ? null
              : [
                  for (final check in checks.values)
                    (
                      at: check.reading.date,
                      values: [
                        check.reading.sgv,
                        check.reading.type.name,
                        check.reading.source.name,
                        check.notes.isEmpty ? null : check.notes.join('\n'),
                      ],
                    ),
                ],
        ),
      },
    ),
  ];
}
