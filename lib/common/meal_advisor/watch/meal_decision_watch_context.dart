import 'package:intl/intl.dart';

import '../../l10n/generated/app_localizations.dart';
import '../context/caregiver_meal_context_history.dart';
import '../context/meal_decision_activity_context.dart';
import '../presentation/meal_decision_carbohydrate_notices.dart';

Map<String, Object?> mealDecisionWatchContext(
  CaregiverMealContextHistory history,
  List<MealDecisionActivityContext> activities,
  AppLocalizations lang,
) {
  String time(DateTime at) =>
      DateFormat.Hm(lang.localeName).format(at.toLocal());
  final glucose = history.readings;
  final devices = history.statuses;
  final last = devices.lastOrNull;
  return {
    'chartStartMs': history.start.millisecondsSinceEpoch,
    'chartEndMs': history.end.millisecondsSinceEpoch,
    'glucoseHistory': [
      for (final reading in glucose)
        [reading.date.millisecondsSinceEpoch, reading.sgv],
    ],
    'iobHistory': [
      for (final status in devices)
        if (status.hasIob && status.iob.isFinite)
          [status.date.millisecondsSinceEpoch, status.iob],
    ],
    'cobHistory': [
      for (final status in devices)
        if (status.hasCob && status.cob.isFinite)
          [status.date.millisecondsSinceEpoch, status.cob],
    ],
    if (last != null && last.hasIob && last.iob.isFinite) 'iob': last.iob,
    if (last != null && last.hasCob && last.cob.isFinite) 'cob': last.cob,
    if (last != null) 'deviceAtMs': last.date.millisecondsSinceEpoch,
    if (history.syncedAt case final DateTime syncedAt)
      'historySyncedAtMs': syncedAt.millisecondsSinceEpoch,
    'notices': [
      for (final window in history.targets)
        lang.mealDecisionDemoTargetWindow(
          '${window.target.targetBottom}–${window.target.targetTop}',
          time(window.target.createdAt),
          time(window.end),
        ),
      ...mealDecisionCarbohydrateMessages(
        history.treatments,
        history.asOf,
        history.asOf.add(const Duration(hours: 4)),
        lang,
      ),
      for (final activity in activities)
        '${activity.name} · ${time(activity.at)} · ${activity.planned
            ? lang.mealDecisionTrainingPlanned
            : activity.endedAt == null
            ? lang.mealDecisionTrainingOngoing
            : lang.mealDecisionTrainingCompleted}',
    ],
  };
}
