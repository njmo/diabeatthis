import 'dart:async';

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/model/meal_status_flow.dart';
import '../../../core/drift/providers/database_provider.dart';
import '../../../features/activity/data/models/activity_log_summary_data.dart';
import '../../../features/caregiver/data/caregiver_visible_state_provider.dart';
import '../../../features/caregiver/presentation/widgets/caregiver_day_view.dart';
import '../../../features/dashboard/data/providers/dashboard_activity_clock_provider.dart';
import '../../../features/dashboard/domain/use_cases/build_dashboard_status_use_case.dart';
import '../../../features/dashboard/presentation/widgets/dashboard_status_card.dart';
import '../../../features/meals/presentation/widgets/meal_progress/meal_schedule_labels.dart';
import '../../../features/meals/presentation/widgets/meal_progress/meal_schedule_tile.dart';
import '../../auth/google_authentication_providers.dart';
import '../../family/family_providers.dart';
import '../../l10n/language.dart';
import '../../meal_advisor/presentation/remote/meal_decision_remote_meal_action.dart';
import '../../meal_advisor/remote/meal_decision_remote_controller.dart';
import '../../monitoring/effective_activity_duration.dart';
import '../../planning/firebase_planning_repository.dart';
import '../../planning/planning_repository_provider.dart';
import '../../presentation/dashboard/dashboard_card_padding.dart';
import '../../presentation/dashboard/dashboard_spacing.dart';
import '../../routing/form_bottom_sheet_route.dart';
import '../../widgets/meal_progress/meal_progress_section_heading.dart';
import '../family_access_scope.dart';
import '../family_plan_submission_store.dart';
import '../family_planning_controller.dart';
import '../family_planning_view.dart';
import 'family_active_meal_card.dart';
import 'family_activity_log_card.dart';
import 'family_activity_plan_form.dart';
import 'family_collections_body.dart';
import 'family_meal_photo_page.dart';
import 'family_meal_plan_form.dart';
import 'family_plan_status_card.dart';
import 'family_planned_activity_card.dart';
import 'family_planned_meal_card.dart';
import 'family_record_page.dart';
import 'family_scope_guard.dart';

class FamilyPlanningPage extends ConsumerStatefulWidget {
  const FamilyPlanningPage({
    super.key,
    this.embedded = false,
    this.view = FamilyPlanningView.all,
    this.header,
    this.headerBuilder,
  });
  final bool embedded;
  final FamilyPlanningView view;
  final Widget? header;
  final Widget Function(bool busy, bool failed, bool ready)? headerBuilder;
  @override
  ConsumerState<FamilyPlanningPage> createState() => FamilyPlanningPageState();
}

class FamilyPlanningPageState extends ConsumerState<FamilyPlanningPage>
    with WidgetsBindingObserver {
  late final controller = FamilyPlanningController(
    ref.read(authenticatedFamilyTransportProvider),
    () => Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.uid,
    FamilyPlanSubmissionStore(ref.read(databaseProvider)),
  );
  final subscriptions = <StreamSubscription>[];
  Timer? retry;
  bool active = true;
  DateTime? selectedDate;
  int daySummaryRevision = 0;
  String? listeningUid;
  final streamHealth = <String, bool>{};
  bool get cloudConnected =>
      streamHealth.length == 2 && streamHealth.values.every((v) => v);
  @override
  void initState() {
    super.initState();
    controller.addListener(changed);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }

  void changed() {
    if (!mounted) return;
    setState(() {});
    if (controller.failed && active && retry == null) {
      retry = Timer(const Duration(seconds: 15), () {
        retry = null;
        if (mounted && active) start();
      });
    } else if (!controller.failed) {
      retry?.cancel();
      retry = null;
    }
  }

  void stop() {
    retry?.cancel();
    retry = null;
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    subscriptions.clear();
    streamHealth.clear();
  }

  void start() {
    if (!mounted || !active) return;
    stop();
    final uid = Firebase.apps.isEmpty
        ? null
        : FirebaseAuth.instance.currentUser?.uid;
    listeningUid = uid;
    unawaited(controller.refresh());
    if (uid == null) return;
    for (final collection in ['familyMirrorSignals', 'familyPlanSignals']) {
      streamHealth[collection] = false;
      subscriptions.add(
        FirebaseFirestore.instance
            .doc('$collection/$uid')
            .snapshots(includeMetadataChanges: true)
            .listen(
              (event) {
                if (mounted && active && listeningUid == uid) {
                  setState(
                    () =>
                        streamHealth[collection] = !event.metadata.isFromCache,
                  );
                }
                if (!event.metadata.isFromCache &&
                    mounted &&
                    active &&
                    listeningUid == uid) {
                  unawaited(controller.refresh());
                }
              },
              onError: (Object error) {
                if (mounted) {
                  controller.clear();
                  controller.failed = true;
                  changed();
                }
              },
            ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (active) {
      start();
    } else {
      stop();
      controller.invalidate();
    }
  }

  @override
  void dispose() {
    stop();
    WidgetsBinding.instance.removeObserver(this);
    controller.removeListener(changed);
    controller.dispose();
    super.dispose();
  }

  Future<void> planFromPhoto() async {
    if (!enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.familyPlanWaitingForChild)),
      );
      return;
    }
    final scope = FamilyAccessScope(controller);
    final uid = scope.uid!, source = scope.source!;
    final rows = controller.rows.values.toList();
    final repository = FirebasePlanningRepository(
      submit: (type, target, values) async {
        scope.requireCurrent();
        await controller.submit(
          type: type,
          targetId: target,
          values: values,
          baseRows: rows,
          expectedUid: uid,
          expectedSource: source,
        );
      },
    );
    final photo = ProviderScope(
      overrides: [planningRepositoryProvider.overrideWithValue(repository)],
      child: FamilyMealPhotoPage(rows: rows),
    );
    await showFormBottomSheet<void>(
      context,
      FamilyScopeGuard(scope: scope, child: photo),
    );
  }

  Future<void> edit(
    String type, {
    int? targetId,
    Map<String, dynamic>? initial,
  }) async {
    final uid = controller.uid, source = controller.source;
    if (uid == null ||
        source == null ||
        !controller.complete ||
        controller.failed) {
      return;
    }
    final rows = controller.rows.values.toList();
    final scope = FamilyAccessScope(controller);
    Future<void> send(Map<String, dynamic> values, {String? operation}) async {
      scope.requireCurrent();
      await controller.submit(
        type: operation ?? type,
        targetId: targetId,
        values: values,
        baseRows: rows,
        expectedSource: source,
        expectedUid: uid,
      );
    }

    if (type == 'confirmActivity' || type == 'skipActivity') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            type == 'skipActivity'
                ? context.lang.activityScheduleNo
                : context.lang.familyPlanConfirm,
          ),
          content: Text(context.lang.familyPlanPendingExplanation),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.lang.familyPlanSend),
            ),
          ],
        ),
      );
      if (accepted == true) {
        try {
          await send({});
        } catch (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.lang.familyPlanFailed)),
            );
          }
        }
      }
      return;
    }
    if (!mounted) return;
    if (type.endsWith('Meal')) {
      await showFormBottomSheet<void>(
        context,
        FamilyScopeGuard(
          scope: scope,
          child: FamilyMealPlanForm(
            rows: rows,
            initial: initial,
            onSubmit: send,
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (context) => FamilyScopeGuard(
        scope: scope,
        child: FamilyActivityPlanForm(
          operation: type,
          targetId: targetId,
          rows: rows,
          initial: initial,
          moveOnly: type == 'moveActivity',
          onSubmit: send,
          onActivitySubmit: (operation, values) =>
              send(values, operation: operation),
        ),
      ),
    );
  }

  Map<String, dynamic> mealValues(Map payload) => {
    'name': payload['name'],
    'category': payload['category'] ?? 'lunch',
    'notes': payload['notes'] ?? '',
    'plannedAt': payload['planned_at'],
    'plannedDay': payload['planned_at'] == null ? payload['planned_day'] : null,
    'ingredients': [
      for (final row
          in controller
              .ofKind('mealIngredients')
              .where((r) => (r['payload'] as Map)['meal_id'] == payload['id']))
        {
          'ingredientId': (row['payload'] as Map)['ingredient_id'],
          'catalogId': null,
          'catalogRevision': null,
          'grams':
              ((row['payload'] as Map)['amount'] as num) *
              (((row['payload'] as Map)['grams_per_portion_used'] as num?) ??
                  1),
        },
    ],
  };
  bool sameDay(int timestamp, DateTime day) =>
      DateUtils.isSameDay(DateTime.fromMillisecondsSinceEpoch(timestamp), day);
  DateTime get day => selectedDate ?? DateUtils.dateOnly(DateTime.now());
  bool get homeLayout =>
      widget.embedded && widget.view == FamilyPlanningView.home;
  bool get showMeals => [
    FamilyPlanningView.all,
    FamilyPlanningView.home,
    FamilyPlanningView.meals,
  ].contains(widget.view);
  bool get showActivities => [
    FamilyPlanningView.all,
    FamilyPlanningView.home,
    FamilyPlanningView.activities,
  ].contains(widget.view);
  bool get showRequests => [
    FamilyPlanningView.all,
    FamilyPlanningView.home,
    FamilyPlanningView.meals,
    FamilyPlanningView.activities,
  ].contains(widget.view);
  List<Map<String, dynamic>> get visibleMeals =>
      controller.ofKind('meals').where((row) {
        final p = row['payload'] as Map;
        if (widget.view == FamilyPlanningView.home) {
          final status = p['status'] as String?;
          return mealStatusAppearsOnDashboard(status) &&
              (status != 'planned' ||
                  (p['planned_at'] is int
                      ? sameDay(p['planned_at'] as int, DateTime.now())
                      : p['planned_day'] ==
                            DateTime.now().toIso8601String().split('T').first));
        }
        return true;
      }).toList()..sort(
        (a, b) =>
            ((a['payload'] as Map)['planned_at'] as int? ?? 0).compareTo(
              (b['payload'] as Map)['planned_at'] as int? ?? 0,
            ) *
            (widget.view == FamilyPlanningView.meals ? -1 : 1),
      );
  List<Map<String, dynamic>> visibleOccurrences(
    DateTime now,
    int? dashboardActivityId,
  ) =>
      controller.ofKind('activityOccurrences').where((row) {
        final p = row['payload'] as Map;
        if (!['pending', 'planned'].contains(p['status'])) return false;
        final logId = p['activity_log_id'];
        final log = controller.rows['activityLogs/$logId']?['payload'] as Map?;
        if (log != null &&
            (logId == dashboardActivityId ||
                (log['started_at'] as int) <= now.millisecondsSinceEpoch)) {
          return false;
        }
        return widget.view != FamilyPlanningView.home ||
            sameDay(p['started_at'] as int, now);
      }).toList()..sort(
        (a, b) => ((a['payload'] as Map)['started_at'] as int).compareTo(
          (b['payload'] as Map)['started_at'] as int,
        ),
      );

  List<Map<String, dynamic>> visibleLogs(DateTime now) =>
      controller.ofKind('activityLogs').where((row) {
        final p = row['payload'] as Map;
        return (p['started_at'] as int) <= now.millisecondsSinceEpoch;
      }).toList()..sort(
        (a, b) => ((b['payload'] as Map)['started_at'] as int).compareTo(
          (a['payload'] as Map)['started_at'] as int,
        ),
      );

  ActivityLogSummaryData? activitySummary(Map log) {
    final activity = controller.rows['activities/${log['activity_id']}'];
    final definition = activity?['payload'] as Map?;
    if (activity?['deleted'] == true || definition == null) return null;
    final occurrence = linkedOccurrence(log['id'] as int);
    final end = log['ended_at'] as int?;
    return ActivityLogSummaryData(
      id: log['id'] as int,
      activityName: definition['name'] as String,
      activityId: log['activity_id'] as int,
      startedAt: DateTime.fromMillisecondsSinceEpoch(log['started_at'] as int),
      endedAt: end == null ? null : DateTime.fromMillisecondsSinceEpoch(end),
      durationMinutes: effectiveActivityDuration(
        activityDuration: definition['duration_minutes'] as int?,
        hasScheduledOccurrence: occurrence != null,
        occurrenceDuration: occurrence?['duration_minutes'] as int?,
      ),
    );
  }

  Map? linkedOccurrence(int activityLogId) => controller
      .ofKind('activityOccurrences')
      .map((row) => row['payload'] as Map)
      .where((row) => row['activity_log_id'] == activityLogId)
      .firstOrNull;

  String? dashboardActivityRequestLabel(BuildContext context, Map? occurrence) {
    if (occurrence == null) return null;
    const kind = 'activityOccurrences';
    final id = occurrence['id'] as int;
    return familyPlanRecordLabel(context, controller.plans, kind, id) ??
        (controller.monitored(kind, id)
            ? context.lang.familyPlanMonitoring
            : controller.locked(kind, id)
            ? context.lang.familyPlanPending
            : null);
  }

  Widget dashboardActivityTrailing(
    BuildContext context,
    ActivityLogSummaryData activity,
    DateTime now,
    Map? occurrence,
  ) {
    final lang = context.lang;
    final open = recordOpener(context, 'activityLogs', activity.id);
    final occurrenceId = occurrence?['id'] as int?;
    if (enabled &&
        activity.startedAt.isAfter(now) &&
        occurrenceId != null &&
        ['planned', 'pending'].contains(occurrence?['status'])) {
      final unlocked = !controller.locked('activityOccurrences', occurrenceId);
      final retry = familyPlanRetryForRecord(
        controller.plans,
        'activityOccurrences',
        occurrenceId,
        edit,
      );
      if (unlocked || retry != null) {
        final scope = FamilyAccessScope(controller);
        void editOccurrence(String operation) {
          final current =
              controller.rows['activityOccurrences/$occurrenceId']?['payload']
                  as Map?;
          if (!mounted ||
              !scope.isCurrent ||
              !enabled ||
              controller.locked('activityOccurrences', occurrenceId) ||
              !['planned', 'pending'].contains(current?['status'])) {
            return;
          }
          edit(
            operation,
            targetId: occurrenceId,
            initial: operation == 'moveActivity'
                ? {'startedAt': current?['started_at']}
                : null,
          );
        }

        return PopupMenuButton<VoidCallback>(
          onSelected: (action) => action(),
          itemBuilder: (context) => [
            PopupMenuItem(value: open, child: Text(lang.activityDetailsTitle)),
            if (retry != null)
              PopupMenuItem(
                value: () {
                  if (mounted && scope.isCurrent && enabled) retry();
                },
                child: Text(lang.familyPlanRetry),
              ),
            if (unlocked) ...[
              PopupMenuItem(
                value: () => editOccurrence('moveActivity'),
                child: Text(lang.activityScheduleMove),
              ),
              PopupMenuItem(
                value: () => editOccurrence('skipActivity'),
                child: Text(lang.activityScheduleNo),
              ),
            ],
          ],
        );
      }
    }
    return IconButton(
      tooltip: lang.activityDetailsTitle,
      icon: const Icon(Icons.open_in_new_rounded),
      onPressed: open,
    );
  }

  bool visibleRequest(Map<String, dynamic> plan) =>
      ![
        'createActivity',
        'updateActivity',
        'createActivitySchedule',
        'setActivityScheduleEnabled',
      ].contains(plan['type']) &&
      showFamilyPlanStatus(plan, controller.rows.values) &&
      (widget.view == FamilyPlanningView.meals
          ? (plan['type'] as String).endsWith('Meal')
          : widget.view == FamilyPlanningView.activities
          ? !(plan['type'] as String).endsWith('Meal')
          : widget.view != FamilyPlanningView.home ||
                plan['status'] != 'applied');
  bool get enabled =>
      controller.complete &&
      !controller.failed &&
      controller.source != null &&
      controller.uid == FirebaseAuth.instance.currentUser?.uid;
  VoidCallback? mealEditor(int id) {
    final scope = FamilyAccessScope(controller);
    bool canEdit() {
      final payload = controller.rows['meals/$id']?['payload'] as Map?;
      return mounted &&
          scope.isCurrent &&
          enabled &&
          !controller.locked('meals', id) &&
          payload?['status'] == 'planned' &&
          payload?['purpose'] == 'meal' &&
          !controller.ofKind('mealIngredients').any((row) {
            final item = row['payload'] as Map;
            return item['meal_id'] == id &&
                item['grams_per_portion_used'] == null;
          });
    }

    if (!canEdit()) return null;
    return () {
      if (!canEdit()) return;
      final payload = controller.rows['meals/$id']!['payload'] as Map;
      edit('updateMeal', targetId: id, initial: mealValues(payload));
    };
  }

  VoidCallback recordOpener(BuildContext context, String kind, int id) {
    final scope = FamilyAccessScope(controller);
    return () => FamilyRecordPage.open(
      context,
      controller,
      kind,
      id,
      scope: scope,
      editMeal: kind == 'meals' ? mealEditor(id) : null,
    );
  }

  Widget _buildActiveMealCard(Map payload) {
    final mealId = payload['id'] as int;
    final decision = ref.watch(
      mealDecisionRemoteControllerProvider.select((inbox) {
        final uid = controller.currentUid();
        if (uid == null || inbox.accountUid != uid) return null;
        final request = inbox.latestForMeal(mealId);
        if (request == null ||
            request.ownerUid != controller.owner ||
            request.sourceId != controller.source ||
            request.status != 'accepted') {
          return null;
        }
        return request.answer?.decision;
      }),
    );
    final history = controller
        .ofKind('mealHistory')
        .map((row) => row['payload'] as Map)
        .where((row) => row['meal_id'] == mealId)
        .map((row) => row['status'])
        .whereType<String>();

    return DashboardCardPadding(
      enabled: true,
      child: FamilyActiveMealCard(
        payload: payload,
        now: DateTime.now(),
        decision: decision,
        history: history,
        monitoring: controller.monitored('meals', mealId),
        decisionAction: MealDecisionRemoteMealAction(mealId: mealId),
        onOpen: recordOpener(context, 'meals', mealId),
      ),
    );
  }

  Widget _buildPlannedMealCard(Map<String, dynamic> row) {
    return DashboardCardPadding(
      enabled: homeLayout,
      child: FamilyPlannedMealCard(
        compact: homeLayout,
        decisionAction: MealDecisionRemoteMealAction(
          mealId: (row['payload'] as Map)['id'] as int,
        ),
        onOpen: recordOpener(
          context,
          'meals',
          (row['payload'] as Map)['id'] as int,
        ),
        onRetry: enabled
            ? familyPlanRetryForRecord(
                controller.plans,
                'meals',
                (row['payload'] as Map)['id'] as int,
                edit,
              )
            : null,
        requestStatusLabel: familyPlanRecordLabel(
          context,
          controller.plans,
          'meals',
          (row['payload'] as Map)['id'] as int,
        ),
        payload: row['payload'] as Map,
        ingredients: controller.ofKind('ingredients'),
        components: controller
            .ofKind('mealIngredients')
            .where(
              (r) =>
                  (r['payload'] as Map)['meal_id'] ==
                  (row['payload'] as Map)['id'],
            )
            .toList(),
        snapshots: controller
            .ofKind('mealSnapshots')
            .where(
              (r) =>
                  (r['payload'] as Map)['meal_id'] ==
                  (row['payload'] as Map)['id'],
            )
            .toList(),
        history: controller
            .ofKind('mealHistory')
            .where(
              (r) =>
                  (r['payload'] as Map)['meal_id'] ==
                  (row['payload'] as Map)['id'],
            )
            .toList(),
        monitoring: controller.monitored(
          'meals',
          (row['payload'] as Map)['id'] as int,
        ),
        locked: controller.locked(
          'meals',
          (row['payload'] as Map)['id'] as int,
        ),
        onEdit: mealEditor((row['payload'] as Map)['id'] as int),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authenticatedFamilyTransportProvider);
    ref.listen(googleAccountProvider, (_, next) {
      if (!next.isLoading && next.asData?.value?.uid != listeningUid) {
        controller.clear();
        stop();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) start();
        });
      }
    });
    if (widget.view == FamilyPlanningView.day) {
      final content = SafeArea(
        bottom: !widget.embedded,
        child: CaregiverDayView(
          date: day,
          today: DateUtils.dateOnly(DateTime.now()),
          owner: controller.owner,
          source: controller.source,
          revision: daySummaryRevision,
          onDateSelected: (date) => setState(() => selectedDate = date),
          onRefresh: () async => setState(() => daySummaryRevision++),
        ),
      );
      return widget.embedded
          ? content
          : Scaffold(
              appBar: AppBar(title: Text(context.lang.dashboardDayTab)),
              body: content,
            );
    }
    if ([
      FamilyPlanningView.meals,
      FamilyPlanningView.activities,
      FamilyPlanningView.ingredients,
      FamilyPlanningView.activityCatalog,
    ].contains(widget.view)) {
      final collection = SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (widget.headerBuilder != null)
              widget.headerBuilder!(
                controller.busy,
                controller.failed ||
                    controller.source != null && !cloudConnected,
                controller.complete,
              ),
            if (widget.header != null) widget.header!,
            if (controller.failed &&
                !controller.busy &&
                widget.headerBuilder == null)
              Text(
                context.lang.familyDataRefreshFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!widget.embedded)
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: enabled ? () => edit('createMeal') : null,
                    icon: const Icon(Icons.restaurant_outlined),
                    label: Text(context.lang.familyPlanMeal),
                  ),
                  OutlinedButton.icon(
                    onPressed: enabled ? () => edit('planActivity') : null,
                    icon: const Icon(Icons.directions_run),
                    label: Text(context.lang.familyPlanActivity),
                  ),
                ],
              ),
            Expanded(
              child:
                  controller.source == null &&
                      !controller.busy &&
                      !controller.failed
                  ? Center(child: Text(context.lang.familyPlanWaitingForChild))
                  : FamilyCollectionsBody(
                      key: ValueKey((
                        controller.uid,
                        controller.owner,
                        controller.source,
                      )),
                      family: controller,
                      view: widget.view,
                      enabled: enabled,
                      edit: edit,
                      mealValues: mealValues,
                    ),
            ),
          ],
        ),
      );
      return widget.embedded
          ? collection
          : Scaffold(
              appBar: AppBar(title: Text(context.lang.familyPlanTitle)),
              body: collection,
            );
    }
    final home = widget.view == FamilyPlanningView.home;
    final logs = home
        ? controller.ofKind('activityLogs').map((row) => row['payload'] as Map)
        : const <Map>[];
    final pending =
        logs
            .where((log) => log['ended_at'] == null)
            .map(activitySummary)
            .nonNulls
            .toList()
          ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final now = home
        ? ref.watch(
            dashboardActivityClockProvider(pending.firstOrNull?.startedAt),
          )
        : clock.now();
    final completed =
        logs
            .where(
              (log) =>
                  log['ended_at'] != null &&
                  log['summarized_at'] == null &&
                  log['summary_dismissed_at'] == null,
            )
            .map(activitySummary)
            .nonNulls
            .toList()
          ..sort((a, b) => b.endedAt!.compareTo(a.endedAt!));
    final target = home
        ? ref.watch(caregiverVisibleStateProvider).snapshot?.temporaryTarget
        : null;
    final status = const BuildDashboardStatusUseCase()(
      now: now,
      pendingActivity: pending.firstOrNull,
      completedActivities: completed,
      target:
          target != null &&
              target.targetBottom > 0 &&
              target.targetTop >= target.targetBottom
          ? target
          : null,
    );
    final activity = status.activity;
    final occurrence = activity == null ? null : linkedOccurrence(activity.id);
    final occurrences = visibleOccurrences(now, activity?.id);
    final historyLogs = home
        ? const <Map<String, dynamic>>[]
        : visibleLogs(now);

    final meals = showMeals ? visibleMeals : const <Map<String, dynamic>>[];
    final activeMeals = <Map<String, dynamic>>[];
    final summaryMeals = <Map<String, dynamic>>[];
    final plannedMeals = <Map<String, dynamic>>[];
    if (homeLayout) {
      for (final row in meals) {
        final status = (row['payload'] as Map)['status'] as String?;
        if (mealStatusBlocksAnotherMealActivation(status)) {
          activeMeals.add(row);
        } else if (mealStatusReadyToSummarize(status)) {
          summaryMeals.add(row);
        } else {
          plannedMeals.add(row);
        }
      }
    }
    final loadingPlannedMeals =
        homeLayout &&
        controller.busy &&
        !controller.complete &&
        plannedMeals.isEmpty;

    final content = SafeArea(
      bottom: !widget.embedded,
      child: RefreshIndicator(
        onRefresh: () async {
          await controller.refresh();
        },
        child: ListView(
          padding: widget.embedded && widget.view == FamilyPlanningView.home
              ? DashboardSpacing.homeScroll(context)
              : EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  widget.embedded
                      ? 112 + MediaQuery.paddingOf(context).bottom
                      : 16,
                ),
          children: [
            if (widget.headerBuilder != null)
              widget.headerBuilder!(
                controller.busy,
                controller.failed ||
                    controller.source != null && !cloudConnected,
                controller.complete,
              ),
            if (widget.header != null) widget.header!,
            if (!widget.embedded)
              Text(context.lang.familyPlanPendingExplanation),
            if (controller.busy &&
                controller.rows.isEmpty &&
                widget.headerBuilder == null)
              const Center(child: CircularProgressIndicator()),
            if (controller.failed &&
                !controller.busy &&
                widget.headerBuilder == null)
              Text(
                context.lang.familyDataRefreshFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!controller.busy &&
                !controller.failed &&
                controller.source == null)
              Text(context.lang.familyPlanWaitingForChild),
            if (!homeLayout) const SizedBox(height: 16),
            if (!widget.embedded)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: enabled ? () => edit('createMeal') : null,
                    icon: const Icon(Icons.restaurant_outlined),
                    label: Text(context.lang.familyPlanMeal),
                  ),
                  OutlinedButton.icon(
                    onPressed: enabled ? () => edit('planActivity') : null,
                    icon: const Icon(Icons.directions_run),
                    label: Text(context.lang.familyPlanActivity),
                  ),
                ],
              ),
            if (home)
              DashboardStatusCards(
                status: status,
                allowLocalActions: false,
                activityRequestLabel:
                    activity != null && activity.startedAt.isAfter(now)
                    ? dashboardActivityRequestLabel(context, occurrence)
                    : null,
                activityTrailing: activity == null
                    ? null
                    : dashboardActivityTrailing(
                        context,
                        activity,
                        now,
                        occurrence,
                      ),
              ),
            if (homeLayout) ...[
              if (activeMeals.isNotEmpty) ...[
                const SizedBox(height: 8),
                DashboardCardPadding(
                  enabled: true,
                  child: MealProgressSectionHeading(
                    title: context.lang.mealProgressCurrent,
                  ),
                ),
                for (final row in activeMeals)
                  _buildActiveMealCard(row['payload'] as Map),
              ],
              if (summaryMeals.isNotEmpty) ...[
                const SizedBox(height: 4),
                DashboardCardPadding(
                  enabled: true,
                  child: MealProgressSectionHeading(
                    title: context.lang.mealProgressToSummarize,
                  ),
                ),
                for (final row in summaryMeals) _buildPlannedMealCard(row),
              ],
              if (plannedMeals.isNotEmpty || loadingPlannedMeals) ...[
                const SizedBox(height: 4),
                DashboardCardPadding(
                  enabled: true,
                  child: Column(
                    children: [
                      MealProgressSectionHeading(
                        title: context.lang.dashboardPlannedMealsTitle,
                      ),
                      MealProgressSectionHeading(
                        title: context.lang.mealProgressToday,
                        date: mealScheduleFullDate(context, now),
                      ),
                      if (loadingPlannedMeals) const MealScheduleLoadingTile(),
                    ],
                  ),
                ),
                for (final row in plannedMeals) _buildPlannedMealCard(row),
              ],
            ] else if (meals.isNotEmpty) ...[
              const SizedBox(height: 16),
              if (!home)
                Text(
                  context.lang.familySyncMeals,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              for (final row in meals) _buildPlannedMealCard(row),
            ],
            if (showActivities &&
                (occurrences.isNotEmpty || historyLogs.isNotEmpty)) ...[
              if (!homeLayout) const SizedBox(height: 16),
              if (widget.view != FamilyPlanningView.home)
                Text(
                  context.lang.familySyncActivityOccurrences,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              for (final row in occurrences)
                DashboardCardPadding(
                  enabled: homeLayout,
                  child: FamilyPlannedActivityCard(
                    onRetry: enabled
                        ? familyPlanRetryForRecord(
                            controller.plans,
                            'activityOccurrences',
                            (row['payload'] as Map)['id'] as int,
                            edit,
                          )
                        : null,
                    requestStatusLabel: familyPlanRecordLabel(
                      context,
                      controller.plans,
                      'activityOccurrences',
                      (row['payload'] as Map)['id'] as int,
                    ),
                    payload: row['payload'] as Map,
                    originalStartedAt:
                        (controller.rows['activityOccurrenceReschedules/${row['id']}']?['payload']
                                as Map?)?['original_started_at']
                            as int?,
                    name:
                        controller
                            .ofKind('activities')
                            .where(
                              (r) =>
                                  r['id'] ==
                                  '${(row['payload'] as Map)['activity_id']}',
                            )
                            .map((r) => (r['payload'] as Map)['name'] as String)
                            .firstOrNull ??
                        context.lang.familyPlanActivity,
                    monitoring: controller.monitored(
                      'activityOccurrences',
                      (row['payload'] as Map)['id'] as int,
                    ),
                    locked: controller.locked(
                      'activityOccurrences',
                      (row['payload'] as Map)['id'] as int,
                    ),
                    onConfirm:
                        enabled &&
                            !controller.locked(
                              'activityOccurrences',
                              (row['payload'] as Map)['id'] as int,
                            )
                        ? () => edit(
                            'confirmActivity',
                            targetId: (row['payload'] as Map)['id'] as int,
                          )
                        : null,
                    onSkip:
                        enabled &&
                            !controller.locked(
                              'activityOccurrences',
                              (row['payload'] as Map)['id'] as int,
                            )
                        ? () => edit(
                            'skipActivity',
                            targetId: (row['payload'] as Map)['id'] as int,
                          )
                        : null,
                    onMove:
                        enabled &&
                            !controller.locked(
                              'activityOccurrences',
                              (row['payload'] as Map)['id'] as int,
                            )
                        ? () => edit(
                            'moveActivity',
                            targetId: (row['payload'] as Map)['id'] as int,
                            initial: {
                              'startedAt':
                                  (row['payload'] as Map)['started_at'],
                            },
                          )
                        : null,
                  ),
                ),
              for (final row in historyLogs)
                DashboardCardPadding(
                  enabled: homeLayout,
                  child: FamilyActivityLogCard(
                    onOpen: recordOpener(
                      context,
                      'activityLogs',
                      (row['payload'] as Map)['id'] as int,
                    ),
                    durationMinutes:
                        (controller
                                    .ofKind('activities')
                                    .where(
                                      (r) =>
                                          r['id'] ==
                                          '${(row['payload'] as Map)['activity_id']}',
                                    )
                                    .firstOrNull?['payload']
                                as Map?)?['duration_minutes']
                            as int?,
                    payload: row['payload'] as Map,
                    name:
                        controller
                            .ofKind('activities')
                            .where(
                              (r) =>
                                  r['id'] ==
                                  '${(row['payload'] as Map)['activity_id']}',
                            )
                            .map((r) => (r['payload'] as Map)['name'] as String)
                            .firstOrNull ??
                        context.lang.familyPlanActivity,
                  ),
                ),
            ],
            if (showRequests && controller.plans.any(visibleRequest)) ...[
              if (!homeLayout) const SizedBox(height: 16),
              for (final plan in controller.plans.where(visibleRequest))
                DashboardCardPadding(
                  enabled: homeLayout,
                  child: FamilyPlanStatusCard(
                    plan: plan,
                    onRetry: enabled
                        ? () => edit(
                            plan['type'] as String,
                            targetId: plan['targetId'] as int?,
                            initial: Map<String, dynamic>.from(
                              plan['values'] as Map,
                            ),
                          )
                        : null,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
    return widget.embedded
        ? content
        : Scaffold(
            appBar: AppBar(title: Text(context.lang.familyPlanTitle)),
            body: content,
          );
  }
}
