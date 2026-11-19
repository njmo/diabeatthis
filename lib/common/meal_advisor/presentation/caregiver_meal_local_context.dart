import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/model/device_status.dart';
import '../../../core/domain/model/glucose.dart';
import '../../../core/domain/model/temporary_target.dart';
import '../../../core/domain/model/treatment_base.dart';
import '../../../features/caregiver/data/caregiver_visible_state_provider.dart';
import '../../../features/meals/presentation/models/meal_page_state.dart';
import '../../family_sync/family_access_scope.dart';
import '../../family_sync/family_planning_controller.dart';
import '../../family_sync/presentation/family_record_page.dart';
import '../../family_sync/presentation/models/family_meal_details.dart';
import '../../l10n/language.dart';
import '../../presentation/details/nightscout_record_history.dart';
import '../../widgets/carbohydrate_totals_summary.dart';
import '../context/caregiver_meal_context_history.dart';
import '../context/meal_decision_activity_context.dart';
import '../remote/meal_decision_remote_request.dart';
import 'caregiver_meal_context_history_view.dart';
import 'meal_decision_activity_card.dart';
import 'meal_decision_activity_glucose_preview.dart';
import 'meal_decision_context_status.dart';

/// Pins local context to the owner and mirror source of the remote request.
FamilyAccessScope? caregiverMealDecisionContextScope(
  FamilyPlanningController family,
  MealDecisionRemoteRequest request,
) {
  final scope = FamilyAccessScope(family);
  if (!scope.isCurrent ||
      scope.owner != request.ownerUid ||
      scope.source != request.sourceId ||
      !family.complete && !family.busy) {
    return null;
  }
  return scope;
}

/// Reads the caregiver's pinned mirror and configured history. No child request
/// payload is used as a source of glucose, nutrition, targets or activity state.
class CaregiverMealLocalContext extends ConsumerWidget {
  const CaregiverMealLocalContext({
    super.key,
    required this.scope,
    required this.mealId,
  });
  final FamilyAccessScope scope;
  final int mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(caregiverVisibleStateProvider);
    final cachedDevice = visible.snapshot?.deviceStatus;
    if (!scope.isCurrent || (!scope.family.complete && !scope.family.busy)) {
      return Text(context.lang.beforeMealUnavailable);
    }
    final rows = scope.family.rows.values.toList();
    MealPageState? state;
    try {
      state = FamilyMealDetails(rows).build(
        mealId,
        context.lang.mealPortionLabel,
        includePlannedPreview: scope.family.complete,
      );
    } catch (_) {
      return Text(context.lang.beforeMealUnavailable);
    }
    if (state == null) {
      return scope.family.busy
          ? const LinearProgressIndicator()
          : Text(context.lang.beforeMealUnavailable);
    }
    final details = state.details;
    final totals = details.preferredNutritionTotals;
    final asOf = clock.now();
    final activities = MealDecisionActivityContext.fromRows(rows, asOf);
    final sameNameMeals =
        scope.family.ofKind('meals').where((row) {
          final p = row['payload'] as Map;
          return p['id'] != mealId &&
              p['name'] == details.meal.name &&
              const {
                'eaten',
                'eaten-extra',
                'eaten-bolused',
                'summarized',
              }.contains(p['status']);
        }).toList()..sort(
          (a, b) =>
              (((b['payload'] as Map)['planned_at'] ??
                          (b['payload'] as Map)['created_at'])
                      as int)
                  .compareTo(
                    ((a['payload'] as Map)['planned_at'] ??
                            (a['payload'] as Map)['created_at'])
                        as int,
                  ),
        );
    final activityNotices = <Widget>[
      for (final activity in activities)
        MealDecisionActivityCard(
          activity: activity,
          glucoseHistory: activity.endedAt == null
              ? null
              : MealDecisionActivityGlucosePreview(
                  scope: scope,
                  logId: activity.id,
                  start: activity.at,
                  end: activity.endedAt!,
                ),
          openRecord: () => FamilyRecordPage.open(
            context,
            scope.family,
            activity.kind,
            activity.id,
            scope: scope,
          ),
          openActivity: activity.planned
              ? null
              : () {
                  final log = rows
                      .where(
                        (row) =>
                            row['kind'] == 'activityLogs' &&
                            row['id'] == '${activity.id}' &&
                            row['deleted'] != true,
                      )
                      .firstOrNull;
                  final activityId = (log?['payload'] as Map?)?['activity_id'];
                  if (activityId is int) {
                    FamilyRecordPage.open(
                      context,
                      scope.family,
                      'activities',
                      activityId,
                      scope: scope,
                    );
                  }
                },
        ),
    ];
    final mealContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Card.outlined(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: const Icon(Icons.restaurant_outlined),
            title: Text(details.meal.name),
            subtitle: Text(
              DateFormat(
                'dd.MM HH:mm',
                context.lang.localeName,
              ).format(details.meal.plannedAt ?? details.meal.createdAt),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => FamilyRecordPage.open(
              context,
              scope.family,
              'meals',
              mealId,
              scope: scope,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (totals == null && scope.family.busy && !scope.family.complete)
          const LinearProgressIndicator()
        else if (totals == null)
          Text(context.lang.similarMealsMissingMacros)
        else
          CarbohydrateTotalsSummary(
            netCarbs: totals.totalNetCarbsG,
            protein: totals.totalProteinG,
            fat: totals.totalFatG,
          ),
        if (sameNameMeals.isNotEmpty)
          ExpansionTile(
            title: Text(context.lang.mealDecisionContextSameNameMeals),
            children: [
              for (final row in sameNameMeals.take(5))
                ListTile(
                  title: Text((row['payload'] as Map)['name'] as String),
                  subtitle: Text(
                    DateFormat('dd.MM HH:mm', context.lang.localeName).format(
                      DateTime.fromMillisecondsSinceEpoch(
                        ((row['payload'] as Map)['planned_at'] ??
                                (row['payload'] as Map)['created_at'])
                            as int,
                      ),
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => FamilyRecordPage.open(
                    context,
                    scope.family,
                    'meals',
                    (row['payload'] as Map)['id'] as int,
                    scope: scope,
                  ),
                ),
            ],
          ),
      ],
    );
    Widget fallback(bool failed) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MealDecisionContextStatus(
          syncedAt: visible.lastSuccess,
          glucoseAt: visible.snapshot?.latestGlucose?.date,
          iobAt: cachedDevice?.hasIob == true && cachedDevice!.iob.isFinite
              ? cachedDevice.date
              : null,
          cobAt: cachedDevice?.hasCob == true && cachedDevice!.cob.isFinite
              ? cachedDevice.date
              : null,
          notices: activityNotices,
          syncFailed: failed || visible.failed,
          syncing: !failed,
        ),
        const SizedBox(height: 12),
        mealContent,
      ],
    );
    return NightscoutRecordHistory<CaregiverMealContextHistory>(
      expandFallback: false,
      keepPreviousDuringRefresh: true,
      refreshKey: visible.lastSuccess,
      fallback: fallback(false),
      errorFallback: fallback(true),
      recordKey: (scope.uid, scope.owner, scope.source, mealId),
      load: (ref, history) async {
        scope.requireCurrent(complete: false);
        final now = clock.now();
        final glucose = history.glucose.fetchGlucoseBetween(
          now.subtract(const Duration(minutes: 30)),
          now,
        );
        final devices = history.deviceStatuses.fetchDeviceStatusBetween(
          now.subtract(const Duration(minutes: 30)),
          now,
        );
        final treatments = history.treatments.fetchTreatmentsBetween(
          now.subtract(const Duration(hours: 24)),
          now.add(const Duration(hours: 4)),
        );
        final all = await Future.wait<Object>([glucose, devices, treatments]);
        final historyTreatments = List<Treatment>.of(all[2] as List<Treatment>);
        final cachedTarget = visible.snapshot?.temporaryTarget;
        if (cachedTarget != null &&
            !historyTreatments.whereType<TemporaryTarget>().any(
              (target) => target.createdAt == cachedTarget.createdAt,
            )) {
          historyTreatments.add(cachedTarget);
        }
        final result = CaregiverMealContextHistory(
          asOf: now,
          syncedAt: clock.now(),
          glucose: all[0] as List<Glucose>,
          devices: all[1] as List<DeviceStatus>,
          treatments: historyTreatments,
        );
        scope.requireCurrent(complete: false);
        return result;
      },
      builder: (history) => CaregiverMealContextHistoryView(
        history: history,
        additionalNotices: activityNotices,
        leadingContent: mealContent,
      ),
    );
  }
}
