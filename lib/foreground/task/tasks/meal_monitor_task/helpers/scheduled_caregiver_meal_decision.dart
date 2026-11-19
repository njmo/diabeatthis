import 'package:clock/clock.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/backend/authenticated_callable_transport.dart';
import '../../../../../common/family/family_providers.dart';
import '../../../../../common/meal_advisor/meal_decision_preferences.dart';
import '../../../../../common/meal_advisor/meal_decision_preferences_provider.dart';
import '../../../../../common/meal_advisor/notifications/meal_decision_push.dart';
import '../../../../../common/meal_advisor/remote/meal_decision_request_creation.dart';
import '../../../../../common/meal_advisor/remote/scheduled_meal_decision_journal.dart';
import '../../../../../common/monitoring/meal_monitoring_phase.dart';
import '../../../../../core/data/provider/shared_prefs_provider.dart';
import '../../../../../core/domain/model/meal.dart';
import '../../../../../core/drift/family_sync/family_mirror_outbox.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../core/firebase/initialize_family_firebase.dart';
import '../../../../../core/logger/logger.dart';
import '../../../../../features/meals/data/providers/meal_activation_guard_provider.dart';
import '../../../base/runtime_context.dart';
import '../meal_monitor_context.dart';

const _requestRetryInterval = Duration(seconds: 30);
const _logTag = 'ScheduledCaregiverMealDecision';

Future<MealDecisionPreferences> _readPreferences(RuntimeContext context) async {
  final prefs = await context.container.read(sharedPrefsProvider.future);
  await prefs.reload();
  return MealDecisionPreferences.decode(
    prefs.getString(mealDecisionPreferencesKey),
  );
}

bool usesCaregiverMealDecision(RuntimeContext context) =>
    context.container.read(mealDecisionPreferencesProvider).method ==
    MealDecisionMethod.caregiver;

Future<bool> _stillUsesCaregiverDecision(RuntimeContext context) async {
  try {
    return (await _readPreferences(context)).method ==
        MealDecisionMethod.caregiver;
  } catch (_) {
    return false;
  }
}

final scheduledCaregiverMealDecisionProvider = Provider(
  (_) => _runScheduledCaregiverMealDecision,
);

Future<bool> _mealIsBlocked(RuntimeContext context, int mealId) async =>
    await context.container.refresh(
      mealBlockingActivationProvider(mealId).future,
    ) !=
    null;

final scheduledMealDecisionUidProvider = Provider<Future<String?> Function()>((
  _,
) {
  Future<void>? initialization;
  return () async {
    try {
      await (initialization ??= initializeFamilyFirebase().timeout(
        const Duration(seconds: 15),
      ));
    } catch (_) {
      initialization = null;
      rethrow;
    }
    return FirebaseAuth.instance.currentUser?.uid;
  };
});

/// Returns false when the monitor should proceed with the local advisor.
Future<bool> _runScheduledCaregiverMealDecision(
  RuntimeContext context,
  MealMonitorContext mealContext,
  Meal meal,
) async {
  final plannedAt = meal.plannedAt!;
  final recoverUntil = plannedAt.add(scheduledMealDecisionRecoveryWindow);
  final untilRequest = plannedAt
      .subtract(scheduledCaregiverRequestLeadTime)
      .difference(clock.now());
  if (untilRequest > Duration.zero) {
    await context.waitForDuration(untilRequest);
  }

  final db = context.container.read(databaseProvider);
  final journal = ScheduledMealDecisionJournal(db);
  final readUid = context.container.read(scheduledMealDecisionUidProvider);
  var saved = await journal.load(meal.id, plannedAt);

  Future<bool> isCurrent() async {
    final stored = await db.mealDao.getMealById(meal.id);
    mealContext.throwIfStopped(context);
    return stored?.status == 'planned' &&
        stored?.plannedAt == plannedAt.millisecondsSinceEpoch;
  }

  ProviderSubscription<AuthenticatedCallableTransport>? holdTransport;
  AuthenticatedCallableTransport transport() =>
      (holdTransport ??= context.container.listen(
        authenticatedFamilyTransportProvider,
        (_, _) {},
      )).read();
  try {
    while (clock.now().isBefore(recoverUntil) && await isCurrent()) {
      if (saved?.handled == true) return true;
      final preferences = await _readPreferences(context);
      if (preferences.method != MealDecisionMethod.caregiver) return false;

      if (await _mealIsBlocked(context, meal.id)) {
        if (!clock.now().isBefore(plannedAt) && saved == null) return true;
        await _waitBeforeRetry(context, recoverUntil);
        continue;
      }

      try {
        final uid = await readUid();
        mealContext.throwIfStopped(context);
        if (saved != null && uid != null && saved.uid != uid) return true;
        if (uid == null) {
          if (saved == null && !clock.now().isBefore(plannedAt)) {
            return preferences.timeoutFallback !=
                MealDecisionTimeoutFallback.app;
          }
          await _waitBeforeRetry(
            context,
            saved == null ? plannedAt : recoverUntil,
          );
          continue;
        }

        final source = await FamilyMirrorOutbox(db).sourceForOwner(uid);
        Map<String, dynamic>? request;
        if (saved != null) {
          final inbox = await transport().call('mealDecision', {
            'action': 'fetch',
          }, expectedUid: uid);
          final lastRequestId = saved.requestId;
          final requests = (inbox['requests'] as List)
              .whereType<Map<String, dynamic>>()
              .where((row) => row['sourceId'] == source);
          request =
              requests.where((row) => row['id'] == lastRequestId).firstOrNull ??
              requests
                  .where(
                    (row) =>
                        row['mealId'].toString() == meal.id.toString() &&
                        (row['createdAt'] as int) >=
                            plannedAt
                                .subtract(scheduledCaregiverRequestLeadTime)
                                .millisecondsSinceEpoch,
                  )
                  .firstOrNull;
          if (request != null && request['id'] != lastRequestId) {
            final serverId = request['id'] as String;
            await journal.remember(
              meal.id,
              plannedAt,
              uid: uid,
              requestId: serverId,
            );
            saved = (uid: uid, requestId: serverId, handled: false);
          }
        }

        if (request == null) {
          if (!clock.now().isBefore(plannedAt)) {
            if (!await isCurrent() || await _mealIsBlocked(context, meal.id)) {
              return true;
            }
            await journal.complete(meal.id, plannedAt);
            return preferences.timeoutFallback !=
                MealDecisionTimeoutFallback.app;
          }

          final requestId = scheduledMealDecisionRequestId(
            source,
            meal.id,
            plannedAt.millisecondsSinceEpoch,
          );
          await journal.remember(
            meal.id,
            plannedAt,
            uid: uid,
            requestId: requestId,
          );
          saved = (uid: uid, requestId: requestId, handled: false);
          request = await transport().call(
            'mealDecision',
            {
              'action': 'create',
              ...mealDecisionCreationData(
                requestId: requestId,
                mealId: meal.id,
                sourceId: source,
                preferences: preferences,
              ),
            },
            expectedUid: uid,
            allowRequest: () async =>
                clock.now().isBefore(plannedAt) &&
                await isCurrent() &&
                await _stillUsesCaregiverDecision(context) &&
                !await _mealIsBlocked(context, meal.id),
          );
          final serverId = request['requestId'] as String;
          await journal.remember(
            meal.id,
            plannedAt,
            uid: uid,
            requestId: serverId,
          );
          saved = (uid: uid, requestId: serverId, handled: false);
        }

        mealContext.throwIfStopped(context);
        final status = request['status'];
        final hadResponse =
            request['response'] != null || request['outcome'] != null;
        if (status == 'waiting' || status == 'open') {
          mealContext.publishStatus(
            context,
            MealMonitoringPhase.waitingForUser,
          );
          final deadline = DateTime.fromMillisecondsSinceEpoch(
            request['deadline'] as int,
          );
          final remaining = deadline.difference(clock.now());
          if (remaining > Duration.zero) {
            await context.waitForDuration(remaining);
          } else {
            await _waitBeforeRetry(context, recoverUntil);
          }
          continue;
        }

        if (status == 'expired' && !hadResponse) {
          final latestPreferences = await _readPreferences(context);
          if (!await isCurrent() || await _mealIsBlocked(context, meal.id)) {
            continue;
          }
          if (latestPreferences.method != MealDecisionMethod.caregiver) {
            return false;
          }
          final manual =
              latestPreferences.timeoutFallback ==
                  MealDecisionTimeoutFallback.manual &&
              latestPreferences.allowManualDecision &&
              request['allowManualDecision'] != false;
          if (manual) {
            if (await readUid() != uid) return true;
            await showScheduledMealDecisionFallback(saved!.requestId);
            if (!await isCurrent() ||
                !await _stillUsesCaregiverDecision(context) ||
                await readUid() != uid) {
              await cancelScheduledMealDecisionFallback(saved.requestId);
            }
          }
          await journal.complete(meal.id, plannedAt, notified: manual);
          return manual;
        }
        // Responded requests are still needed by the child, but no fallback is due.
        await journal.complete(meal.id, plannedAt);
        return true;
      } catch (error) {
        mealContext.throwIfStopped(context);
        if (error is CallableFailure &&
            const {
              'permission-denied',
              'invalid-argument',
            }.contains(error.rejectionCode)) {
          return true;
        }
        Log.w(
          _logTag,
          'Request or deadline check unavailable: ${error.runtimeType}',
        );
        await _waitBeforeRetry(
          context,
          saved == null ? plannedAt : recoverUntil,
        );
        if (saved == null && !clock.now().isBefore(plannedAt)) {
          return preferences.timeoutFallback != MealDecisionTimeoutFallback.app;
        }
      }
    }
    return true;
  } finally {
    holdTransport?.close();
  }
}

Future<void> _waitBeforeRetry(RuntimeContext context, DateTime until) async {
  final remaining = until.difference(clock.now());
  if (remaining > Duration.zero) {
    await context.waitForDuration(
      remaining < _requestRetryInterval ? remaining : _requestRetryInterval,
    );
  }
}
