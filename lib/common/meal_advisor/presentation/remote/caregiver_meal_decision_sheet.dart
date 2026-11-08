import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../../family/family_providers.dart';
import '../../../family_sync/family_access_scope.dart';
import '../../../family_sync/family_plan_submission_store.dart';
import '../../../family_sync/family_planning_controller.dart';
import '../../../l10n/language.dart';
import '../../../widgets/meal_start/meal_start_sheet.dart';
import '../../demo/meal_decision_demo_answer.dart';
import '../../meal_decision_preferences_provider.dart';
import '../../remote/meal_decision_remote_controller.dart';
import '../caregiver_meal_local_context.dart';
import '../demo/meal_decision_demo_options.dart';
import 'meal_decision_presentation_registry.dart';
import 'meal_decision_remote_outcome.dart';

Future<void> showCaregiverMealDecisionRequest(
  BuildContext context,
  String requestId, {
  String action = 'open',
  bool waitForClose = true,
}) async {
  if (!MealDecisionPresentationRegistry.caregiverRequests.add(requestId)) {
    if (action == 'open') {
      return;
    }
    final handle = MealDecisionPresentationRegistry.caregiverActions[requestId];
    if (handle == null) throw StateError('The request is still opening');
    await handle(action);
    return;
  }
  try {
    final closed = showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => CaregiverMealDecisionSheet(
        requestId: requestId,
        initialAction: action,
      ),
    );
    if (waitForClose) {
      await closed;
    } else {
      unawaited(
        closed.whenComplete(
          () => MealDecisionPresentationRegistry.caregiverRequests.remove(
            requestId,
          ),
        ),
      );
      return;
    }
  } finally {
    if (waitForClose) {
      MealDecisionPresentationRegistry.caregiverRequests.remove(requestId);
    }
  }
}

class CaregiverMealDecisionSheet extends HookConsumerWidget {
  const CaregiverMealDecisionSheet({
    super.key,
    required this.requestId,
    this.initialAction = 'open',
  });
  final String requestId, initialAction;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(mealDecisionRemoteControllerProvider);
    final request = inbox.accountUid == FirebaseAuth.instance.currentUser?.uid
        ? inbox.byId(requestId)
        : null;
    final remote = ref.read(mealDecisionRemoteControllerProvider.notifier);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final busy = useState(false);
    final failed = useState(false);
    final stage = useState('context');
    final active = useAppLifecycleState() == AppLifecycleState.resumed;
    final tick = useState(DateTime.now());
    final answer = useState(MealDecisionDemoAnswer.insulinAndEat);
    final minutes = useTextEditingController(
      text: '${ref.read(mealDecisionPreferencesProvider).deferralMinutes}',
    );
    final message = useTextEditingController();
    final target = useState(false);
    final family = useMemoized(
      () => FamilyPlanningController(
        ref.read(authenticatedFamilyTransportProvider),
        () => FirebaseAuth.instance.currentUser?.uid,
        FamilyPlanSubmissionStore(ref.read(databaseProvider)),
      ),
      [uid],
    );
    useListenable(family);
    final mirrorUnavailable = useState(false);
    useEffect(() {
      unawaited(family.refresh());
      return family.dispose;
    }, [family]);
    useEffect(() {
      if (uid == null || Firebase.apps.isEmpty) {
        return null;
      }
      final subscription = FirebaseFirestore.instance
          .doc('familyMirrorSignals/$uid')
          .snapshots()
          .listen(
            (event) {
              if (!event.metadata.isFromCache &&
                  FirebaseAuth.instance.currentUser?.uid == uid) {
                unawaited(family.refresh());
              }
            },
            onError: (Object _) {
              if (context.mounted) mirrorUnavailable.value = true;
            },
          );
      return () {
        unawaited(subscription.cancel());
      };
    }, [family, uid]);
    final owned = request?.claimedByUid == uid && uid != null;
    final locked =
        owned && request?.pending == true && request?.status == 'waiting';
    Future<bool> run(
      String action, [
      Map<String, Object?> data = const {},
    ]) async {
      busy.value = true;
      failed.value = false;
      try {
        await remote.execute(action, {'requestId': requestId, ...data});
        return true;
      } catch (_) {
        if (context.mounted) failed.value = true;
        return false;
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    Future<void> delegate() async {
      if (request == null) return;
      if (!owned && !await run('claim')) return;
      if (!context.mounted) return;
      final current = ref
          .read(mealDecisionRemoteControllerProvider)
          .byId(requestId);
      final selection = await showDialog<String>(
        context: context,
        builder: (dialog) => SimpleDialog(
          title: Text(context.lang.mealDecisionNotificationDelegate),
          children: [
            for (final person in current?.members ?? <Map<String, dynamic>>[])
              if (person['uid'] != uid && person['enabled'] == true)
                SimpleDialogOption(
                  onPressed: () =>
                      Navigator.of(dialog).pop(person['uid'] as String),
                  child: Text(person['displayName'] as String? ?? ''),
                ),
          ],
        ),
      );
      if (selection != null &&
          await run('delegate', {'caregiverUid': selection}) &&
          context.mounted) {
        Navigator.of(context).pop();
      }
    }

    useEffect(() {
      Future<void> handle(String action) async {
        if (action == 'claim') await run('claim');
        if (action == 'delegate') await delegate();
        if (action == 'decline' && await run('decline') && context.mounted) {
          Navigator.of(context).pop();
        }
      }

      MealDecisionPresentationRegistry.installCaregiverHandler(
        requestId,
        handle,
      );
      return () {
        MealDecisionPresentationRegistry.removeCaregiverHandler(
          requestId,
          handle,
        );
      };
    }, [requestId, request, owned]);
    useEffect(() {
      final timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => tick.value = DateTime.now(),
      );
      Future.microtask(() async {
        await remote.refresh();
        if (!context.mounted) return;
        if (initialAction == 'claim') await run('claim');
        if (initialAction == 'delegate') await delegate();
        if (initialAction == 'decline' &&
            await run('decline') &&
            context.mounted) {
          Navigator.of(context).pop();
        }
      });
      return timer.cancel;
    }, [requestId]);
    final heartbeatQueue = useRef(Future<void>.value());
    void heartbeat(bool present) {
      heartbeatQueue.value = heartbeatQueue.value.then((_) async {
        try {
          await remote.execute('heartbeat', {
            'requestId': requestId,
            'stage': stage.value,
            'present': present,
          }, refresh: false);
        } catch (_) {
          /* Presence expires server-side if the connection is lost. */
        }
      });
    }

    useEffect(() {
      if (!locked) return null;
      heartbeat(active);
      final timer = active
          ? Timer.periodic(const Duration(seconds: 15), (_) => heartbeat(true))
          : null;
      return () {
        timer?.cancel();
        heartbeat(false);
      };
    }, [locked, active, requestId]);
    useEffect(() {
      if (locked && active) heartbeat(true);
      return null;
    }, [stage.value]);
    final valid =
        request != null &&
        family.owner == request.ownerUid &&
        family.source == request.sourceId &&
        (family.complete || family.busy && family.source != null) &&
        !family.failed &&
        !mirrorUnavailable.value;
    return PopScope(
      canPop: !locked,
      child: MealStartSheet(
        maxHeightFactor: .75,
        title: request?.mealName ?? context.lang.mealDecisionNotificationTitle,
        subtitle:
            '${stage.value == 'context' ? '1' : '2'}/2 · ${stage.value == 'context' ? context.lang.mealDecisionRemoteContext : context.lang.mealDecisionRemoteDecision}',
        showClose: !locked,
        onClose: locked ? null : () => Navigator.of(context).pop(),
        onBack: locked && stage.value == 'decision'
            ? () => stage.value = 'context'
            : null,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (request == null)
              Text(
                inbox.loading
                    ? context.lang.mealDecisionRemoteWaiting
                    : context.lang.mealDecisionRemoteUnavailable,
              )
            else if (request.expired)
              MealDecisionRemoteOutcome(request: request)
            else if (request.status == 'accepted')
              Text(context.lang.mealDecisionRemoteAccepted)
            else if (request.status == 'answered')
              Text(context.lang.mealDecisionRemoteResponded)
            else if (!owned &&
                request.claimedByUid != null &&
                !request.claimAvailable)
              Text(
                '${context.lang.mealDecisionRemoteAlreadyTaken}\n${request.claimedByName ?? ''}',
              )
            else if (stage.value == 'context')
              valid
                  ? CaregiverMealLocalContext(
                      scope: FamilyAccessScope(family),
                      mealId: request.mealId,
                    )
                  : family.failed || mirrorUnavailable.value
                  ? Text(context.lang.familyDataRefreshFailed)
                  : const LinearProgressIndicator()
            else ...[
              MealDecisionDemoOptions(
                value: answer.value,
                onChanged: busy.value
                    ? (_) {}
                    : (value) {
                        answer.value = value;
                      },
              ),
              if (answer.value.requiresMinutes)
                TextField(
                  controller: minutes,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: context.lang.mealDecisionRemoteMinutes,
                  ),
                ),
              TextField(
                controller: message,
                maxLength: 240,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: context.lang.mealDecisionRemoteMessage,
                ),
              ),
              if (answer.value == MealDecisionDemoAnswer.deferMeal)
                CheckboxListTile(
                  value: target.value,
                  onChanged: (value) => target.value = value ?? false,
                  title: Text(context.lang.mealDecisionMealTargetSuggested),
                ),
            ],
            if (failed.value)
              Text(
                context.lang.mealDecisionRemoteFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        actions: busy.value
            ? const LinearProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (request?.pending == true &&
                      request?.status == 'waiting' &&
                      (owned || request?.claimAvailable == true)) ...[
                    if (!owned)
                      FilledButton(
                        onPressed: () => run('claim'),
                        child: Text(context.lang.mealDecisionNotificationClaim),
                      )
                    else if (stage.value == 'context')
                      FilledButton(
                        onPressed: valid
                            ? () => stage.value = 'decision'
                            : null,
                        child: Text(context.lang.mealDecisionRemoteNext),
                      )
                    else
                      FilledButton(
                        onPressed: () async {
                          final wait = answer.value.requiresMinutes
                              ? int.tryParse(minutes.text)
                              : null;
                          if (answer.value.requiresMinutes &&
                              (wait == null || wait < 1 || wait > 180)) {
                            failed.value = true;
                            return;
                          }
                          if (await run('respond', {
                                'decision': {
                                  'type': answer.value.name,
                                  'minutes': wait,
                                  'message': message.text.trim(),
                                  'targetSuggestion':
                                      answer.value ==
                                              MealDecisionDemoAnswer
                                                  .deferMeal &&
                                          target.value
                                      ? context
                                            .lang
                                            .mealDecisionMealTargetSuggested
                                      : null,
                                },
                              }) &&
                              context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(context.lang.mealDecisionRemoteSend),
                      ),
                    OutlinedButton(
                      onPressed: delegate,
                      child: Text(
                        context.lang.mealDecisionNotificationDelegate,
                      ),
                    ),
                    if (!owned)
                      TextButton(
                        onPressed: () async {
                          if (await run('decline') && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(
                          context.lang.mealDecisionNotificationDecline,
                        ),
                      ),
                  ],
                  if (inbox.failed || family.failed)
                    TextButton(
                      onPressed: () async {
                        await remote.refresh();
                        await family.refresh();
                      },
                      child: Text(context.lang.commonRetry),
                    ),
                ],
              ),
      ),
    );
  }
}
