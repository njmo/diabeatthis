import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/drift/database_impl.dart';
import '../../../core/drift/providers/database_provider.dart';
import '../../../features/dashboard/data/repositories/meal_advisor_result_store.dart';
import '../../../features/dashboard/data/use_cases/accept_meal_decision_use_case.dart';
import '../../../features/dashboard/data/use_cases/meal_advisor_result_use_case.dart';
import '../../../features/meal_advisor/domain/models/meal_advice.dart';
import '../../../features/meal_advisor/domain/models/wait_suggestion.dart';
import '../../app_mode/application_device_mode.dart';
import '../../auth/google_authentication_providers.dart';
import '../../family/family_providers.dart';
import '../../meal/meal_activation_guard.dart';
import '../meal_decision_answer.dart';
import 'meal_decision_remote_controller.dart';
import 'meal_decision_remote_request.dart';

final acceptRemoteMealDecisionProvider = Provider(
  (ref) => AcceptRemoteMealDecision(ref),
);

class AcceptRemoteMealDecision {
  const AcceptRemoteMealDecision(this.ref);
  final Ref ref;

  Future<MealAdvice?> call(
    MealDecisionRemoteRequest request, {
    MealAdvice? reviewedAdvice,
    bool startMeal = false,
    bool Function()? isCancelled,
  }) async {
    final beganBeforeDeadline = DateTime.now().isBefore(request.deadline);
    final uid = ref.read(googleAccountProvider).asData?.value?.uid;
    if (uid != request.ownerUid ||
        ref.read(authenticatedFamilyTransportProvider).currentUid() != uid ||
        await ref.read(applicationDeviceModeProvider.future) !=
            ApplicationDeviceMode.patient) {
      throw StateError('Not the child owner');
    }
    if (reviewedAdvice != null &&
        (reviewedAdvice.source != 'caregiver' ||
            reviewedAdvice.caregiverId != request.respondingCaregiverUid ||
            reviewedAdvice.caregiverRequestId != request.id ||
            reviewedAdvice.decision != request.answer?.decision ||
            (reviewedAdvice.wait?.recommendedMinutes ?? 0) !=
                request.minutes)) {
      throw StateError('Reviewed decision differs from the caregiver response');
    }
    if (isCancelled?.call() == true) {
      throw StateError('The meal choice changed');
    }
    final remote = ref.read(mealDecisionRemoteControllerProvider.notifier);
    final prepared = await remote.execute('prepareAcceptance', {
      'requestId': request.id,
      'sourceId': request.sourceId,
    }, refresh: false);
    final token = prepared['acceptanceToken'] as String;
    final db = ref.read(databaseProvider);
    final answer = request.answer;
    final advice =
        reviewedAdvice ??
        (answer?.decision == null
            ? null
            : MealAdvice(
                answer!.decision,
                answer == MealDecisionAnswer.insulinThenWait
                    ? WaitSuggestion(
                        request.minutes,
                        request.minutes,
                        request.minutes,
                      )
                    : null,
                source: 'caregiver',
                caregiverId: request.respondingCaregiverUid,
                caregiverRequestId: request.id,
              ));
    try {
      if (isCancelled?.call() == true) {
        throw StateError('The meal choice changed');
      }
      await db.transaction(() async {
        if (isCancelled?.call() == true) {
          throw StateError('The meal choice changed');
        }
        if (ref.read(googleAccountProvider).asData?.value?.uid != uid ||
            ref.read(authenticatedFamilyTransportProvider).currentUid() !=
                uid ||
            ref.read(applicationDeviceModeProvider).asData?.value !=
                ApplicationDeviceMode.patient) {
          throw StateError('Account or mode changed');
        }
        final identity = await db
            .customSelect(
              'SELECT owner_uid,source_id FROM family_sync_identity WHERE singleton=1',
            )
            .getSingle();
        if (identity.readNullable<String>('owner_uid') != uid ||
            identity.read<String>('source_id') != request.sourceId) {
          throw StateError('Mirror source changed');
        }
        await ensureMealActivationAllowed(
          db,
          request.mealId,
          allowedStatuses: const {'planned'},
        );
        final saved = await db
            .customSelect(
              'SELECT request_id FROM family_meal_decision_receipts WHERE request_id=? AND owner_uid=?',
              variables: [Variable(request.id), Variable(uid!)],
            )
            .getSingleOrNull();
        if (saved != null) return;
        if (!beganBeforeDeadline) {
          throw StateError(
            'The caregiver decision expired before confirmation',
          );
        }
        final version = await db
            .customSelect(
              "SELECT revision FROM family_sync_outbox WHERE kind='meals' AND entity_id=?",
              variables: [Variable('${request.mealId}')],
            )
            .getSingleOrNull();
        if (version?.read<int>('revision') != request.data['mealRevision']) {
          throw StateError('The meal changed since the request');
        }
        if (advice != null) {
          if (startMeal) {
            await AcceptMealDecisionUseCase(ref).call(request.mealId, advice);
          } else {
            await MealAdvisorResultUseCase(
              DriftMealAdvisorResultStore(dao: db.mealAdvisorResultDao),
            ).saveMealAdvice(request.mealId, advice);
          }
        } else if (answer == MealDecisionAnswer.deferMeal) {
          final responded = request.response?['respondedAt'] as int;
          await (db.update(
            db.meal,
          )..where((row) => row.id.equals(request.mealId))).write(
            MealCompanion(
              plannedAt: Value(
                responded + Duration(minutes: request.minutes).inMilliseconds,
              ),
              plannedDay: const Value(null),
              isSynced: const Value(false),
            ),
          );
        } else {
          throw StateError('No valid caregiver answer');
        }
        await db.customStatement(
          'INSERT INTO family_meal_decision_receipts(request_id,owner_uid,source_id,meal_id,acceptance_token,outcome_json,created_at) VALUES(?,?,?,?,?,?,?)',
          [
            request.id,
            uid,
            request.sourceId,
            request.mealId,
            token,
            jsonEncode({
              'source': 'caregiver',
              'decision': answer!.name,
              'minutes': answer.requiresMinutes ? request.minutes : null,
              'caregiverUid': request.respondingCaregiverUid,
            }),
            DateTime.now().millisecondsSinceEpoch,
          ],
        );
      });
    } catch (_) {
      // The transaction rolled back, so no local result may be acknowledged.
      try {
        await remote.execute('abortAcceptance', {
          'requestId': request.id,
          'sourceId': request.sourceId,
          'acceptanceToken': token,
        });
      } catch (_) {
        /* A retry can recover the same reservation. */
      }
      rethrow;
    }
    // Durable receipt is replayed without blocking the child on an ACK connection.
    await reconcileMealDecisionReceipts(ref);
    return advice;
  }
}

final reconcileMealDecisionReceiptsProvider = Provider(
  (ref) =>
      () => reconcileMealDecisionReceipts(ref),
);

Future<void> reconcileMealDecisionReceipts(Ref ref) async {
  final uid = ref.read(googleAccountProvider).asData?.value?.uid;
  if (uid == null ||
      ref.read(applicationDeviceModeProvider).asData?.value !=
          ApplicationDeviceMode.patient) {
    return;
  }
  final db = ref.read(databaseProvider);
  final rows = await db
      .customSelect(
        'SELECT * FROM family_meal_decision_receipts WHERE owner_uid=? AND acknowledged=0',
        variables: [Variable(uid)],
      )
      .get();
  for (final row in rows) {
    if (!ref.mounted ||
        ref.read(googleAccountProvider).asData?.value?.uid != uid ||
        ref.read(authenticatedFamilyTransportProvider).currentUid() != uid) {
      return;
    }
    try {
      final token = row.read<String>('acceptance_token');
      final outcome =
          jsonDecode(row.read<String>('outcome_json')) as Map<String, dynamic>;
      await ref.read(mealDecisionRemoteControllerProvider.notifier).execute(
        outcome['source'] == 'caregiver' ? 'acknowledge' : 'expire',
        {
          'requestId': row.read<String>('request_id'),
          'sourceId': row.read<String>('source_id'),
          if (token.isNotEmpty) 'acceptanceToken': token,
          'outcome': outcome,
        },
      );
      await db.customStatement(
        'UPDATE family_meal_decision_receipts SET acknowledged=1 WHERE request_id=? AND owner_uid=?',
        [row.read<String>('request_id'), uid],
      );
    } catch (_) {
      // An offline receipt remains durable and will be retried on resume/signals.
    }
  }
}
