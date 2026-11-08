import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/drift/providers/database_provider.dart';
import '../../../features/caregiver/presentation/widgets/caregiver_day_view.dart';
import '../../auth/google_authentication_providers.dart';
import '../../family/family_providers.dart';
import '../../l10n/language.dart';
import '../../meal_advisor/presentation/remote/meal_decision_remote_meal_action.dart';
import '../../planning/firebase_planning_repository.dart';
import '../../planning/planning_repository_provider.dart';
import '../../presentation/dashboard/dashboard_card_padding.dart';
import '../../presentation/dashboard/dashboard_spacing.dart';
import '../../routing/form_bottom_sheet_route.dart';
import '../family_access_scope.dart';
import '../family_plan_submission_store.dart';
import '../family_planning_controller.dart';
import '../family_planning_view.dart';
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
          return sameDay(p['planned_at'] as int, DateTime.now()) ||
              ![
                'planned',
                'summarized',
                'skipped',
                'interrupted',
              ].contains(p['status']);
        }
        return true;
      }).toList()..sort(
        (a, b) =>
            ((a['payload'] as Map)['planned_at'] as int).compareTo(
              (b['payload'] as Map)['planned_at'] as int,
            ) *
            (widget.view == FamilyPlanningView.meals ? -1 : 1),
      );
  List<Map<String, dynamic>> get visibleOccurrences =>
      controller.ofKind('activityOccurrences').where((row) {
        final p = row['payload'] as Map;
        if (!['pending', 'planned'].contains(p['status'])) return false;
        final log =
            controller.rows['activityLogs/${p['activity_log_id']}']?['payload']
                as Map?;
        if (log != null &&
            (log['started_at'] as int) <=
                DateTime.now().millisecondsSinceEpoch) {
          return false;
        }
        if (widget.view == FamilyPlanningView.home) {
          return sameDay(p['started_at'] as int, DateTime.now());
        }
        return true;
      }).toList()..sort(
        (a, b) => ((a['payload'] as Map)['started_at'] as int).compareTo(
          (b['payload'] as Map)['started_at'] as int,
        ),
      );
  List<Map<String, dynamic>> get visibleLogs =>
      controller.ofKind('activityLogs').where((row) {
        final p = row['payload'] as Map;
        if ((p['started_at'] as int) > DateTime.now().millisecondsSinceEpoch) {
          return false;
        }
        if (widget.view == FamilyPlanningView.home) {
          return p['ended_at'] == null;
        }
        return true;
      }).toList()..sort(
        (a, b) => ((b['payload'] as Map)['started_at'] as int).compareTo(
          (a['payload'] as Map)['started_at'] as int,
        ),
      );
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
  VoidCallback recordOpener(BuildContext context, String kind, int id) {
    final scope = FamilyAccessScope(controller);
    return () =>
        FamilyRecordPage.open(context, controller, kind, id, scope: scope);
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
            if (showMeals && visibleMeals.isNotEmpty) ...[
              if (!homeLayout) const SizedBox(height: 16),
              if (widget.view != FamilyPlanningView.home)
                Text(
                  context.lang.familySyncMeals,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              for (final row in visibleMeals)
                DashboardCardPadding(
                  enabled: homeLayout,
                  child: FamilyPlannedMealCard(
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
                    onEdit:
                        enabled &&
                            !controller.locked(
                              'meals',
                              (row['payload'] as Map)['id'] as int,
                            )
                        ? () => edit(
                            'updateMeal',
                            targetId: (row['payload'] as Map)['id'] as int,
                            initial: mealValues(row['payload'] as Map),
                          )
                        : null,
                  ),
                ),
            ],
            if (showActivities &&
                (visibleOccurrences.isNotEmpty || visibleLogs.isNotEmpty)) ...[
              if (!homeLayout) const SizedBox(height: 16),
              if (widget.view != FamilyPlanningView.home)
                Text(
                  context.lang.familySyncActivityOccurrences,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              for (final row in visibleOccurrences)
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
              for (final row in visibleLogs)
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
