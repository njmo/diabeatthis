import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/day_summary_snapshot.dart';
import 'day_summary_facts.dart';

class DaySummaryReviewForm extends StatefulWidget {
  final DaySummarySnapshot snapshot;
  final bool saving;
  final Future<void> Function(Set<int>, bool)? onAccept;
  const DaySummaryReviewForm({
    super.key,
    required this.snapshot,
    this.onAccept,
    this.saving = false,
  });

  @override
  State<DaySummaryReviewForm> createState() => DaySummaryReviewFormState();
}

class DaySummaryReviewFormState extends State<DaySummaryReviewForm> {
  final skipped = <int>{};
  bool acknowledge = false;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final saving = widget.saving;
    final editable = widget.onAccept != null;
    final unresolved = [
      for (var i = 0; i < snapshot.review.length; i++)
        if (snapshot.review[i].resolution == DaySummaryResolution.unresolved) i,
    ];
    final ready =
        (snapshot.limitations.isEmpty || acknowledge) &&
        unresolved.every(skipped.contains);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.lang.daySummaryDataUntil(
            DateFormat(
              'dd.MM.yyyy HH:mm',
              context.lang.localeName,
            ).format(snapshot.displayTime(snapshot.asOf)),
          ),
        ),
        if (snapshot.nightStart != null && snapshot.nightEnd != null)
          Text(
            context.lang.daySummaryNightRange(
              DateFormat(
                'dd.MM HH:mm',
                context.lang.localeName,
              ).format(snapshot.displayTime(snapshot.nightStart!)),
              DateFormat(
                'dd.MM HH:mm',
                context.lang.localeName,
              ).format(snapshot.displayTime(snapshot.nightEnd!)),
            ),
          ),
        Text(context.lang.dayReviewDataNote),
        if (snapshot.limitations.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            context.lang.daySummaryGaps(
              snapshot.limitations
                  .map(
                    (key) =>
                        limitationLabels(context)[key] ??
                        context.lang.daySourceUnavailable,
                  )
                  .join(', '),
            ),
          ),
          if (editable)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: acknowledge,
              onChanged: saving
                  ? null
                  : (value) => setState(() => acknowledge = value ?? false),
              title: Text(context.lang.dayReviewAcceptGaps),
            ),
        ],
        if (unresolved.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            editable
                ? context.lang.dayReviewUnresolved
                : context.lang.dayReviewLeftUnresolved,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (editable) Text(context.lang.dayReviewSkipNote),
          for (final index in unresolved)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: editable ? skipped.contains(index) : true,
              onChanged: !editable || saving
                  ? null
                  : (value) => setState(() {
                      if (value == true) {
                        skipped.add(index);
                      } else {
                        skipped.remove(index);
                      }
                    }),
              title: Text(
                '${DateFormat('HH:mm').format(snapshot.displayTime(snapshot.review[index].occurredAt))} · ${snapshot.review[index].kind == DaySummaryReviewKind.meal ? context.lang.dayReviewMealEntry : context.lang.dayReviewPossibleLow}',
              ),
              subtitle: Text(context.lang.dayReviewLeaveUnresolved),
            ),
        ],
        const SizedBox(height: 12),
        DaySummaryFacts(snapshot: snapshot),
        if (editable) ...[
          const SizedBox(height: 16),
          Text(context.lang.dayReviewImmutableNote),
          FilledButton(
            onPressed: ready && !saving
                ? () => widget.onAccept!(Set.of(skipped), acknowledge)
                : null,
            child: Text(
              saving
                  ? context.lang.manualEventSaving
                  : context.lang.dayReviewAccept,
            ),
          ),
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: Text(context.lang.dayReviewReturn),
          ),
        ],
      ],
    );
  }

  static Map<String, String> limitationLabels(BuildContext context) => {
    'glucose': context.lang.daySummarySourceGlucose,
    'nightGlucose': context.lang.daySummarySourceNightGlucose,
    'deviceStatus': context.lang.daySummarySourceDeviceStatus,
    'treatments': context.lang.daySummarySourceTreatments,
    'basal': context.lang.daySummarySourceBasal,
    'nightBasal': context.lang.daySummarySourceNightBasal,
    'meals': context.lang.daySummarySourceMeals,
    'lowTreatments': context.lang.daySummarySourceLowTreatments,
    'activities': context.lang.daySummarySourceActivities,
    'sensorAge': context.lang.daySummarySourceSensorAge,
    'podAge': context.lang.daySummarySourcePodAge,
    'mealReview': context.lang.daySummarySourceMealReview,
    'lowTreatmentReview': context.lang.daySummarySourceLowTreatmentReview,
  };
}
