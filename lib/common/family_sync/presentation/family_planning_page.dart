import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/drift/providers/database_provider.dart';
import '../../auth/google_authentication_providers.dart';
import '../../family/family_providers.dart';
import '../../l10n/language.dart';
import '../family_plan_submission_store.dart';
import '../family_planning_controller.dart';
import 'family_activity_plan_form.dart';
import 'family_meal_plan_form.dart';
import 'family_plan_request_card.dart';
import 'family_planned_activity_card.dart';
import 'family_planned_meal_card.dart';

class FamilyPlanningPage extends ConsumerStatefulWidget {
  const FamilyPlanningPage({super.key});
  @override
  ConsumerState<FamilyPlanningPage> createState() => FamilyPlanningPageState();
}

class FamilyPlanningPageState extends ConsumerState<FamilyPlanningPage>
    with WidgetsBindingObserver {
  late final controller = FamilyPlanningController(
    ref.read(authenticatedFamilyTransportProvider),
    () => FirebaseAuth.instance.currentUser?.uid,
    FamilyPlanSubmissionStore(ref.read(databaseProvider)),
  );
  final subscriptions = <StreamSubscription>[];
  Timer? retry;
  bool active = true;
  String? listeningUid;
  @override
  void initState() {
    super.initState();
    controller.addListener(changed);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
  }

  void changed() {
    if (mounted) setState(() {});
  }

  void stop() {
    retry?.cancel();
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    subscriptions.clear();
  }

  void start() {
    if (!mounted || !active) return;
    stop();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    listeningUid = uid;
    unawaited(controller.refresh());
    retry = Timer.periodic(
      const Duration(seconds: 60),
      (_) => unawaited(controller.refresh()),
    );
    if (uid != null) {
      for (final collection in ['familyMirrorSignals', 'familyPlanSignals']) {
        subscriptions.add(
          FirebaseFirestore.instance
              .doc('$collection/$uid')
              .snapshots()
              .listen(
                (event) {
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
    Future<void> send(Map<String, dynamic> values) => controller.submit(
      type: type,
      targetId: targetId,
      values: values,
      baseRows: rows,
      expectedSource: source,
      expectedUid: uid,
    );
    if (type == 'confirmActivity') {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.lang.familyPlanConfirm),
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
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: type.endsWith('Meal')
            ? FamilyMealPlanForm(rows: rows, initial: initial, onSubmit: send)
            : FamilyActivityPlanForm(
                rows: rows,
                initial: initial,
                moveOnly: type == 'moveActivity',
                onSubmit: send,
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
  bool get enabled =>
      controller.complete &&
      !controller.failed &&
      controller.source != null &&
      controller.uid == FirebaseAuth.instance.currentUser?.uid;
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
    return Scaffold(
      appBar: AppBar(title: Text(context.lang.familyPlanTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(context.lang.familyPlanPendingExplanation),
              if (controller.busy) const LinearProgressIndicator(),
              if (controller.failed)
                Text(
                  context.lang.familyPlanFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (!controller.busy &&
                  !controller.failed &&
                  controller.source == null)
                Text(context.lang.familyPlanWaitingForChild),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              Text(
                context.lang.familySyncMeals,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final row in controller.ofKind('meals'))
                FamilyPlannedMealCard(
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
              const SizedBox(height: 16),
              Text(
                context.lang.familySyncActivityOccurrences,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final row
                  in controller
                      .ofKind('activityOccurrences')
                      .where(
                        (r) => (r['payload'] as Map)['status'] != 'deleted',
                      ))
                FamilyPlannedActivityCard(
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
                            'startedAt': (row['payload'] as Map)['started_at'],
                          },
                        )
                      : null,
                ),
              const SizedBox(height: 16),
              Text(
                context.lang.familyPlanRequests,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              for (final plan in controller.plans)
                FamilyPlanRequestCard(
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
            ],
          ),
        ),
      ),
    );
  }
}
