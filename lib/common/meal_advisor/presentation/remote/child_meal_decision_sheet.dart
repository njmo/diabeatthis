import 'dart:async';
import 'dart:math';

import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/drift/family_sync/family_mirror_outbox.dart';
import '../../../../core/drift/mappers/meal_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../features/dashboard/data/providers/device_status_ui_provider.dart';
import '../../../auth/google_authentication_providers.dart';
import '../../../l10n/language.dart';
import '../../../widgets/meal_start/meal_start_sheet.dart';
import '../../meal_decision_answer.dart';
import '../../meal_decision_preferences.dart';
import '../../meal_decision_preferences_provider.dart';
import '../../remote/accept_remote_meal_decision.dart';
import '../../remote/capture_meal_advisor_suggestion.dart';
import '../../remote/meal_decision_remote_controller.dart';
import '../../remote/meal_decision_request_creation.dart';
import '../../remote/meal_decision_resolution.dart';
import '../meal_decision_deadline_panel.dart';
import 'child_meal_decision_answer.dart';
import 'child_meal_decision_fallback_notice.dart';
import 'meal_decision_caregiver_roster.dart';
import 'meal_decision_meal_reference.dart';
import 'meal_decision_presentation_registry.dart';

final childMealDecisionRequestPresenterProvider =
    Provider<
      Future<MealDecisionResolution?> Function(BuildContext, int, String)
    >((ref) => presentChildMealDecisionRequest);

Future<MealDecisionResolution?> presentChildMealDecisionRequest(
  BuildContext context,
  int mealId,
  String mealName,
) => showChildMealDecisionRequest(context, mealId: mealId, mealName: mealName);

Future<MealDecisionResolution?> showChildMealDecisionRequest(
  BuildContext context, {
  required int mealId,
  required String mealName,
}) async {
  if (!MealDecisionPresentationRegistry.childMeals.add(mealId)) return null;
  try {
    return await showModalBottomSheet<MealDecisionResolution>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ChildMealDecisionSheet(mealId: mealId, mealName: mealName),
    );
  } finally {
    MealDecisionPresentationRegistry.childMeals.remove(mealId);
  }
}

class ChildMealDecisionSheet extends HookConsumerWidget {
  const ChildMealDecisionSheet({
    super.key,
    required this.mealId,
    required this.mealName,
    this.onResolved,
    this.initialRequestId,
  });
  final int mealId;
  final String mealName;
  final String? initialRequestId;
  final ValueChanged<MealDecisionResolution>? onResolved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(mealDecisionRemoteControllerProvider);
    final preferences = ref.watch(mealDecisionPreferencesProvider);
    final requestId = useState<String?>(initialRequestId);
    final failed = useState(false);
    final busy = useState(false);
    final now = useState(DateTime.now());
    final provisionalDeadline = useMemoized(
      () => DateTime.now().add(const Duration(minutes: 5)),
    );
    final request = requestId.value == null
        ? inbox.forMeal(mealId)
        : inbox.byId(requestId.value!);
    final deadline = request?.deadline ?? provisionalDeadline;
    final expired = request?.status == 'accepting'
        ? false
        : !now.value.isBefore(deadline) ||
              (request?.status == 'expired' &&
                  request?.data['acceptanceAborted'] != true);
    final allDeclined =
        expired && request?.data['terminalReason'] == 'allCaregiversDeclined';
    final popped = useRef(false);
    final closed = useRef(false);
    void close() {
      if (closed.value) return;
      closed.value = true;
      final route = ModalRoute.of(context);
      if (route != null && route.isActive)
        Navigator.of(context).removeRoute(route);
    }

    void resolve(MealDecisionResolution resolution) {
      if (closed.value) return;
      if (onResolved != null) {
        onResolved!(resolution);
      } else {
        Navigator.of(context).pop(resolution);
      }
    }

    Future<void> send() async {
      if (!context.mounted || closed.value) return;
      busy.value = true;
      failed.value = false;
      try {
        final controller = ref.read(
          mealDecisionRemoteControllerProvider.notifier,
        );
        await controller.refresh();
        if (!context.mounted || closed.value) return;
        final refreshed = ref.read(mealDecisionRemoteControllerProvider);
        final existing = initialRequestId == null
            ? refreshed.forMeal(mealId)
            : refreshed.byId(initialRequestId!);
        if (initialRequestId != null && existing == null) {
          throw StateError('Meal decision request unavailable');
        }
        if (existing != null) {
          if (context.mounted) requestId.value = existing.id;
          if (existing.status == 'accepting' &&
              !DateTime.now().isBefore(existing.deadline)) {
            final committed = await ref
                .read(databaseProvider)
                .customSelect(
                  'SELECT request_id FROM family_meal_decision_receipts WHERE request_id=?',
                  variables: [Variable(existing.id)],
                )
                .getSingleOrNull();
            if (committed == null) {
              final reserved = await controller.execute('prepareAcceptance', {
                'requestId': existing.id,
                'sourceId': existing.sourceId,
              }, refresh: false);
              await controller.execute('abortAcceptance', {
                'requestId': existing.id,
                'sourceId': existing.sourceId,
                'acceptanceToken': reserved['acceptanceToken'],
              });
            } else {
              await ref.read(reconcileMealDecisionReceiptsProvider)();
            }
          }
          return;
        }
        final uid = ref.read(googleAccountProvider).asData?.value?.uid;
        if (uid == null) throw StateError('Google authentication required');
        final source = await FamilyMirrorOutbox(
          ref.read(databaseProvider),
        ).sourceForOwner(uid);
        final storedMeal = await ref
            .read(databaseProvider)
            .mealDao
            .getMealById(mealId);
        if (!context.mounted || closed.value) return;
        if (storedMeal == null || storedMeal.status != 'planned') {
          throw StateError('Meal is no longer planned');
        }
        final draftId = requestId.value;
        final draftExpired =
            draftId != null && refreshed.byId(draftId)?.expired == true;
        final random = Random.secure();
        final id =
            (draftExpired ? null : draftId) ??
            List.generate(
              32,
              (_) => random.nextInt(16).toRadixString(16),
            ).join();
        if (context.mounted) requestId.value = id;
        final suggestion = await ref.read(captureMealAdvisorSuggestionProvider)(
          storedMeal.toDomain(),
          ref.read(deviceStatusUiProvider),
        );
        if (!context.mounted || closed.value) return;
        final created = await controller.execute(
          'create',
          mealDecisionCreationData(
            requestId: id,
            mealId: mealId,
            sourceId: source,
            preferences: preferences,
            advisorSuggestion: suggestion,
          ),
        );
        if (context.mounted) {
          requestId.value = created['requestId'] as String? ?? id;
        }
      } catch (_) {
        if (context.mounted) failed.value = true;
      } finally {
        if (context.mounted) busy.value = false;
      }
    }

    useEffect(() {
      final timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => now.value = DateTime.now(),
      );
      Future.microtask(send);
      return timer.cancel;
    }, [mealId]);
    useEffect(() {
      if (expired && !allDeclined && !busy.value && !popped.value) {
        popped.value = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            resolve(
              MealDecisionResolution(
                fallback:
                    preferences.allowManualDecision &&
                        request?.data['allowManualDecision'] != false
                    ? preferences.timeoutFallback
                    : MealDecisionTimeoutFallback.app,
                request: request,
              ),
            );
          }
        });
      }
      return null;
    }, [expired, allDeclined, busy.value]);
    final knownId = requestId.value ?? request?.id;
    final answer = request?.answer;
    Future<void> retryRead() async {
      await ref.read(mealDecisionRemoteControllerProvider.notifier).refresh();
      if (context.mounted && knownId != null) {
        final refreshed = ref.read(mealDecisionRemoteControllerProvider);
        if (!refreshed.failed && refreshed.byId(knownId) != null) {
          failed.value = false;
        }
      }
    }

    useEffect(() {
      if (!inbox.retryableReadFailure ||
          knownId == null ||
          expired ||
          answer != null ||
          busy.value) {
        return null;
      }
      final timer = Timer(const Duration(seconds: 2), () {
        if (context.mounted) unawaited(retryRead());
      });
      return timer.cancel;
    }, [inbox, knownId, expired, answer, busy.value]);

    if (allDeclined && request != null) {
      final fallback =
          preferences.allowManualDecision &&
              request.data['allowManualDecision'] != false
          ? preferences.timeoutFallback
          : MealDecisionTimeoutFallback.app;
      return ChildMealDecisionFallbackNotice(
        key: ValueKey(request.id),
        mealName: mealName,
        request: request,
        fallback: fallback,
        onClose: close,
        onContinue: () {
          if (popped.value) return;
          popped.value = true;
          resolve(MealDecisionResolution(fallback: fallback, request: request));
        },
      );
    }
    return PopScope(
      canPop: false,
      child: MealStartSheet(
        title: answer == null
            ? request != null
                  ? context.lang.mealDecisionRequestSent
                  : failed.value
                  ? context.lang.mealDecisionRemoteFailed
                  : context.lang.mealDecisionRemoteWaiting
            : context.lang.mealDecisionAnswerTitle,
        subtitle: answer == null && request != null
            ? context.lang.mealDecisionWaitingDescription
            : '',
        maxHeightFactor: .75,
        onClose: close,
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MealDecisionMealReference(name: mealName),
            const SizedBox(height: 20),
            if (answer == null) ...[
              if (request != null) ...[
                MealDecisionCaregiverRoster(request: request),
                if (request.status == 'waiting' && !expired) ...[
                  MealDecisionDeadlinePanel(
                    deadline: request.deadline,
                    fallback:
                        preferences.allowManualDecision &&
                            request.data['allowManualDecision'] != false
                        ? preferences.timeoutFallback
                        : MealDecisionTimeoutFallback.app,
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ],
            if (answer != null) ChildMealDecisionAnswer(request: request!),
            if (failed.value || inbox.failed)
              Text(
                context.lang.mealDecisionRemoteFailed,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
        actions: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (failed.value && answer == null)
              TextButton(
                onPressed: busy.value
                    ? null
                    : knownId == null
                    ? send
                    : retryRead,
                child: Text(context.lang.commonRetry),
              ),
            if (answer != null &&
                preferences.allowManualDecision &&
                request?.data['allowManualDecision'] != false)
              TextButton(
                onPressed: busy.value
                    ? null
                    : () async {
                        busy.value = true;
                        failed.value = false;
                        try {
                          await ref
                              .read(acceptRemoteMealDecisionProvider)
                              .reject(request!);
                          if (context.mounted) {
                            resolve(
                              const MealDecisionResolution(rejected: true),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) failed.value = true;
                        } finally {
                          if (context.mounted) busy.value = false;
                        }
                      },
                child: Text(context.lang.notificationActionReject),
              ),
            if (answer != null)
              FilledButton(
                onPressed: busy.value
                    ? null
                    : () async {
                        busy.value = true;
                        failed.value = false;
                        try {
                          final advice = answer == MealDecisionAnswer.deferMeal
                              ? await ref.read(
                                  acceptRemoteMealDecisionProvider,
                                )(request!)
                              : request!.advice;
                          if (context.mounted) {
                            resolve(
                              MealDecisionResolution(
                                advice: advice,
                                request: request,
                                deferred:
                                    answer == MealDecisionAnswer.deferMeal,
                              ),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) failed.value = true;
                        } finally {
                          if (context.mounted) busy.value = false;
                        }
                      },
                child: busy.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.lang.mealDecisionDemoAccept),
              ),
          ],
        ),
      ),
    );
  }
}
