import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../../family/family_providers.dart';
import '../../../family_sync/family_plan_submission_store.dart';
import '../../../family_sync/family_planning_controller.dart';
import '../../../l10n/language.dart';
import '../../../routing/owned_route_registry.dart';
import '../../../widgets/meal_start/meal_start_sheet.dart';
import '../../meal_decision_answer.dart';
import '../../meal_decision_preferences_provider.dart';
import '../../notifications/meal_decision_push.dart';
import '../../remote/caregiver_meal_decision_eligibility.dart';
import '../../remote/meal_decision_presence_controller.dart';
import '../../remote/meal_decision_remote_controller.dart';
import '../caregiver_meal_local_context.dart';
import '../meal_decision_deadline_panel.dart';
import '../meal_decision_default_minutes.dart';
import '../meal_decision_options.dart';
import 'caregiver_meal_decision_invitation.dart';
import 'caregiver_meal_decision_timeout.dart';
import 'meal_decision_answered_status.dart';
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
  var sheetOwnsRegistry = false;
  try {
    final inbox = ProviderScope.containerOf(
      context,
      listen: false,
    ).read(mealDecisionRemoteControllerProvider);
    final request = inbox.byId(requestId);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (request == null || !caregiverCanOpenMealDecision(request, uid)) {
      await cancelMealDecisionNotification(requestId);
      return;
    }
    if (request.claimedByUid != null &&
        request.claimedByUid != uid &&
        !request.claimAvailable) {
      await cancelMealDecisionNotification(requestId);
      return;
    }
    if (action == 'decline') {
      await ProviderScope.containerOf(context, listen: false)
          .read(mealDecisionRemoteControllerProvider.notifier)
          .execute('decline', {'requestId': requestId});
      await cancelMealDecisionNotification(requestId);
      return;
    }
    var nextAction = action;
    if (request.claimedByUid != uid) {
      if (action == 'claim' || action == 'delegate') {
        await ProviderScope.containerOf(context, listen: false)
            .read(mealDecisionRemoteControllerProvider.notifier)
            .execute('claim', {'requestId': requestId});
      } else {
        final accepted = await showModalBottomSheet<String>(
          context: context,
          useRootNavigator: true,
          useSafeArea: true,
          isScrollControlled: true,
          isDismissible: false,
          enableDrag: false,
          backgroundColor: Colors.transparent,
          builder: (_) => CaregiverMealDecisionInvitation(requestId: requestId),
        );
        if (accepted != 'claim' && accepted != 'delegate') return;
        nextAction = accepted!;
      }
    }
    if (!context.mounted) return;
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
        initialAction: nextAction == 'delegate' ? nextAction : 'open',
      ),
    );
    if (waitForClose) {
      await closed;
    } else {
      sheetOwnsRegistry = true;
      unawaited(
        closed.whenComplete(() {
          MealDecisionPresentationRegistry.caregiverRequests.remove(requestId);
          MealDecisionPresentationRegistry.changes.add(null);
        }),
      );
      return;
    }
  } finally {
    if (!sheetOwnsRegistry) {
      MealDecisionPresentationRegistry.caregiverRequests.remove(requestId);
      MealDecisionPresentationRegistry.changes.add(null);
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
    final delegateRoute = useRef<Route<dynamic>?>(null);
    final busy = useState(false);
    final failed = useState(false);
    final stage = useState('context');
    final tick = useState(DateTime.now());
    final answer = useState(MealDecisionAnswer.insulinAndEat);
    final minutes = useTextEditingController();
    final message = useTextEditingController();
    final family = useMemoized(
      () => FamilyPlanningController(
        ref.read(authenticatedFamilyTransportProvider),
        () => FirebaseAuth.instance.currentUser?.uid,
        FamilyPlanSubmissionStore(ref.read(databaseProvider)),
      ),
      [uid],
    );
    final sheetRoute = ModalRoute.of(context);
    final sheetNavigator = Navigator.of(context);
    void closeSheet({bool keepSheet = false}) {
      if (!sheetNavigator.mounted) return;
      OwnedRouteRegistry.close(family);
      final nested = delegateRoute.value;
      if (nested != null &&
          nested.isActive &&
          nested.navigator == sheetNavigator) {
        sheetNavigator.removeRoute(nested);
      }
      if (!keepSheet &&
          sheetRoute != null &&
          sheetRoute.isActive &&
          sheetRoute.navigator == sheetNavigator) {
        sheetNavigator.removeRoute(sheetRoute);
      }
    }

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
    final timedOut =
        uid != null &&
        inbox.accountUid == uid &&
        request?.timedOutAt(tick.value) == true;
    final unavailable =
        uid == null ||
        inbox.accountUid != uid ||
        (!inbox.loading &&
            !inbox.failed &&
            (request == null ||
                !request.pending ||
                request.status != 'waiting' ||
                (request.claimedByUid != null &&
                    request.claimedByUid != uid &&
                    !request.claimAvailable)));
    useEffect(() {
      if (unavailable) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(cancelMealDecisionNotification(requestId));
          if (context.mounted) closeSheet(keepSheet: timedOut);
        });
      }
      return null;
    }, [unavailable, timedOut, family]);
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
      void unavailable() {
        if (!context.mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.lang.mealDecisionNoDelegateAvailable)),
        );
      }

      await remote.refresh();
      if (!context.mounted) return;
      var current = ref
          .read(mealDecisionRemoteControllerProvider)
          .byId(requestId);
      if (current == null ||
          mealDecisionDelegateCandidates(current, uid).isEmpty) {
        unavailable();
        return;
      }
      if (current.claimedByUid != uid && !await run('claim')) return;
      if (!context.mounted) return;
      current = ref.read(mealDecisionRemoteControllerProvider).byId(requestId);
      final candidates = current == null
          ? const <Map<String, dynamic>>[]
          : mealDecisionDelegateCandidates(current, uid);
      if (candidates.isEmpty) {
        unavailable();
        return;
      }
      final selection = await showDialog<String>(
        context: context,
        builder: (dialog) {
          delegateRoute.value = ModalRoute.of(dialog);
          return SimpleDialog(
            title: Text(context.lang.mealDecisionNotificationDelegate),
            children: [
              for (final person in candidates)
                SimpleDialogOption(
                  onPressed: () =>
                      Navigator.of(dialog).pop(person['uid'] as String),
                  child: Text(person['displayName'] as String? ?? ''),
                ),
            ],
          );
        },
      );
      delegateRoute.value = null;
      if (selection != null &&
          await run('delegate', {'caregiverUid': selection}) &&
          context.mounted) {
        closeSheet();
      }
    }

    useEffect(() {
      Future<void> handle(String action) async {
        if (action == 'claim') await run('claim');
        if (action == 'delegate') await delegate();
        if (action == 'decline' && await run('decline') && context.mounted) {
          closeSheet();
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
          closeSheet();
        }
      });
      return timer.cancel;
    }, [requestId]);
    final presence = useMemoized(
      () => MealDecisionPresenceController((stage, present) async {
        await remote.execute('heartbeat', {
          'requestId': requestId,
          'stage': stage,
          'present': present,
        }, refresh: false);
      }),
      [requestId, remote],
    );
    useEffect(() {
      presence.start();
      return presence.dispose;
    }, [presence]);
    useEffect(() {
      presence.update(enabled: locked, stage: stage.value);
      return null;
    }, [presence, locked, stage.value]);
    final contextScope = request == null || mirrorUnavailable.value
        ? null
        : caregiverMealDecisionContextScope(family, request);
    if (timedOut && request != null) {
      return CaregiverMealDecisionTimeout(
        request: request,
        onClose: closeSheet,
      );
    }
    return PopScope(
      canPop: !locked,
      child: MealStartSheet(
        maxHeightFactor: .75,
        title: request?.mealName ?? context.lang.mealDecisionNotificationTitle,
        subtitle:
            '${stage.value == 'context' ? '1' : '2'}/2 · ${stage.value == 'context' ? context.lang.mealDecisionRemoteContext : context.lang.mealDecisionRemoteDecision}',
        showClose: !locked,
        onClose: locked ? null : closeSheet,
        onBack: locked && stage.value == 'decision'
            ? () => stage.value = 'context'
            : null,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (request != null &&
                request.status == 'waiting' &&
                !request.expired) ...[
              MealDecisionDeadlinePanel(
                deadline: request.deadline,
                fallback: null,
              ),
              const SizedBox(height: 16),
            ],
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
              const MealDecisionAnsweredStatus()
            else if (!owned &&
                request.claimedByUid != null &&
                !request.claimAvailable)
              Text(
                '${context.lang.mealDecisionRemoteAlreadyTaken}\n${request.claimedByName ?? ''}',
              )
            else if (stage.value == 'context')
              contextScope != null
                  ? CaregiverMealLocalContext(
                      scope: contextScope,
                      mealId: request.mealId,
                    )
                  : family.failed || mirrorUnavailable.value
                  ? Text(context.lang.familyDataRefreshFailed)
                  : const LinearProgressIndicator()
            else ...[
              MealDecisionOptions(
                value: answer.value,
                onChanged: busy.value
                    ? (_) {}
                    : (value) {
                        if (value != answer.value && value.requiresMinutes) {
                          minutes.text =
                              '${mealDecisionDefaultMinutes(value, deferralMinutes: ref.read(mealDecisionPreferencesProvider).deferralMinutes)}';
                        }
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
                        onPressed: contextScope != null
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
                                  'targetSuggestion': null,
                                },
                              }) &&
                              context.mounted) {
                            closeSheet();
                          }
                        },
                        child: Text(context.lang.mealDecisionRemoteSend),
                      ),
                    if (request != null &&
                        mealDecisionDelegateCandidates(request, uid).isNotEmpty)
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
                            closeSheet();
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
