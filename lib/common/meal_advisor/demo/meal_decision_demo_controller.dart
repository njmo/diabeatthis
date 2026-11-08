import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/meal_advisor/domain/models/meal_advice.dart';
import '../../../features/meal_advisor/domain/models/wait_suggestion.dart';
import '../../auth/google_authentication_providers.dart';
import '../meal_decision_preferences.dart';
import '../meal_decision_preferences_provider.dart';
import 'meal_decision_demo_answer.dart';
import 'meal_decision_demo_caregiver.dart';
import 'meal_decision_demo_request.dart';
import 'meal_decision_demo_snapshot.dart';

final mealDecisionDemoDelayProvider = Provider<Future<void> Function()>(
  (ref) =>
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
);
final mealDecisionDemoControllerProvider =
    NotifierProvider<
      MealDecisionDemoController,
      Map<String, MealDecisionDemoRequest>
    >(MealDecisionDemoController.new);

/// A replaceable in-memory demo adapter. No database, Firebase or AAPS writes.
class MealDecisionDemoController
    extends Notifier<Map<String, MealDecisionDemoRequest>> {
  int sequence = 0;
  final responseTimers = <String, Timer>{};
  @override
  Map<String, MealDecisionDemoRequest> build() {
    ref.watch(
      googleAccountProvider.select((account) => account.asData?.value?.uid),
    );
    ref.onDispose(() {
      for (final timer in responseTimers.values) {
        timer.cancel();
      }
      responseTimers.clear();
    });
    return const {};
  }

  Future<void> send(
    String key,
    String mealName, {
    int? mealId,
    String? childOwner,
    String? mirrorSource,
  }) async {
    final current = state[key];
    if (current != null &&
        {
          MealDecisionDemoStatus.sending,
          MealDecisionDemoStatus.waiting,
          MealDecisionDemoStatus.answered,
        }.contains(current.status)) {
      return;
    }
    final request = MealDecisionDemoRequest(
      id: 'demo-${++sequence}',
      childOwner: childOwner,
      mirrorSource: mirrorSource,
      mealId:
          mealId ??
          (key.startsWith('patient:')
              ? int.tryParse(key.substring('patient:'.length))
              : null),
      key: key,
      mealName: mealName,
      snapshot: MealDecisionDemoSnapshot(capturedAt: clock.now()),
      status: MealDecisionDemoStatus.sending,
    );
    state = {...state, key: request};
    responseTimers.remove(key)?.cancel();
    responseTimers[key] = Timer(
      const Duration(minutes: 5),
      () => expireRequest(key, request.id),
    );
    await ref.read(mealDecisionDemoDelayProvider)();
    if (!ref.mounted ||
        state[key]?.id != request.id ||
        state[key]?.status != MealDecisionDemoStatus.sending) {
      return;
    }
    state = {...state, key: request.withStatus(MealDecisionDemoStatus.waiting)};
  }

  bool claim(
    String key,
    String id,
    String caregiverName, {
    String caregiverId = 'demo-caregiver',
  }) {
    final current = state[key];
    final name = caregiverName.trim();
    if (current == null ||
        current.id != id ||
        current.status != MealDecisionDemoStatus.waiting ||
        !clock.now().isBefore(current.responseDeadline) ||
        name.isEmpty ||
        caregiverId.trim().isEmpty ||
        (current.claimedById != null &&
            current.claimedById != caregiverId &&
            !current.claimExpired &&
            (current.claimExpiresAt == null ||
                clock.now().isBefore(current.claimExpiresAt!)))) {
      return false;
    }
    state = {
      ...state,
      key: current.withStatus(
        current.status,
        claimedBy: name,
        claimedById: caregiverId,
        caregiverPresent: true,
        stage: MealDecisionDemoStage.context,
        claimExpired: false,
        claimExpiresAt: current.responseDeadline,
      ),
    };
    return true;
  }

  bool updateCaregiverContext(
    String key,
    String id,
    String caregiverId, {
    required bool present,
    MealDecisionDemoStage? stage,
  }) {
    if (!ref.mounted) return false;
    final current = state[key];
    if (current == null ||
        current.id != id ||
        current.claimedById != caregiverId ||
        current.status != MealDecisionDemoStatus.waiting) {
      return false;
    }
    state = {
      ...state,
      key: current.withStatus(
        current.status,
        caregiverPresent: present,
        stage: stage,
      ),
    };
    return true;
  }

  bool transfer(String key, String id, String caregiverId, String targetId) {
    final current = state[key];
    final target = ref
        .read(mealDecisionDemoCaregiversProvider)
        .where((person) => person.id == targetId)
        .firstOrNull;
    if (current == null ||
        current.id != id ||
        current.status != MealDecisionDemoStatus.waiting ||
        current.claimedById != caregiverId ||
        target == null ||
        targetId == caregiverId ||
        current.claimExpired ||
        (current.claimExpiresAt != null &&
            !clock.now().isBefore(current.claimExpiresAt!))) {
      return false;
    }
    state = {
      ...state,
      key: current.withStatus(
        current.status,
        claimedBy: target.name,
        claimedById: target.id,
        caregiverPresent: false,
        stage: MealDecisionDemoStage.context,
        claimExpired: false,
        claimExpiresAt: current.responseDeadline,
        transferredFrom: current.claimedBy,
        transferredTo: target.name,
      ),
    };
    return true;
  }

  bool expireClaim(
    String key,
    String id,
    String caregiverId,
    DateTime deadline,
  ) {
    if (!ref.mounted) return false;
    final current = state[key];
    if (current == null ||
        current.claimedById != caregiverId ||
        current.claimExpiresAt != deadline) {
      return false;
    }
    return expireRequest(key, id);
  }

  bool expireRequest(String key, String id) {
    if (!ref.mounted) return false;
    final current = state[key];
    if (current == null ||
        current.id != id ||
        !{
          MealDecisionDemoStatus.sending,
          MealDecisionDemoStatus.waiting,
        }.contains(current.status) ||
        clock.now().isBefore(current.responseDeadline)) {
      return false;
    }
    responseTimers.remove(key)?.cancel();
    final fallback = ref.read(mealDecisionPreferencesProvider).timeoutFallback;
    state = {
      ...state,
      key: current.withStatus(
        MealDecisionDemoStatus.timedOut,
        clearClaim: true,
        caregiverPresent: false,
        claimExpired: true,
        timeoutFallback: fallback,
      ),
    };
    return true;
  }

  bool completeFallback(String key, String id, MealAdvice advice) {
    final current = state[key];
    if (current == null ||
        current.id != id ||
        current.status != MealDecisionDemoStatus.timedOut ||
        current.fallbackAdvice != null ||
        advice.decision == null) {
      return false;
    }
    final sources =
        current.timeoutFallback == MealDecisionTimeoutFallback.manual
        ? const {'manual', 'manualDemo'}
        : const {'mealAdvisor', 'mealAdvisorDemo'};
    if (!sources.contains(advice.source)) return false;
    state = {
      ...state,
      key: current.withStatus(current.status, fallbackAdvice: advice),
    };
    return true;
  }

  bool respond(
    String key,
    String id, {
    required MealDecisionDemoAnswer answer,
    required int minutes,
    required String caregiverName,
    String caregiverId = 'demo-caregiver',
    String message = '',
    bool suggestMealTarget = false,
  }) {
    final current = state[key];
    if (current == null ||
        current.id != id ||
        current.status != MealDecisionDemoStatus.waiting) {
      return false;
    }
    if (!clock.now().isBefore(current.responseDeadline) ||
        current.claimExpired ||
        (current.claimExpiresAt != null &&
            !clock.now().isBefore(current.claimExpiresAt!)) ||
        (current.claimedById != null && current.claimedById != caregiverId) ||
        caregiverName.trim().isEmpty ||
        caregiverId.trim().isEmpty ||
        message.characters.length > 240) {
      return false;
    }
    if (answer.requiresMinutes && (minutes < 1 || minutes > 180)) return false;
    responseTimers.remove(key)?.cancel();
    state = {
      ...state,
      key: MealDecisionDemoRequest(
        id: id,
        mealId: current.mealId,
        childOwner: current.childOwner,
        mirrorSource: current.mirrorSource,
        key: key,
        mealName: current.mealName,
        snapshot: current.snapshot,
        status: MealDecisionDemoStatus.answered,
        claimedBy: caregiverName.trim(),
        claimedById: caregiverId,
        caregiverId: caregiverId,
        transferredFrom: current.transferredFrom,
        transferredTo: current.transferredTo,
        answer: answer,
        waitMinutes: answer.requiresMinutes ? minutes : 0,
        caregiverName: caregiverName.trim(),
        message: message.trim(),
        suggestMealTarget:
            answer == MealDecisionDemoAnswer.deferMeal && suggestMealTarget,
        deferredUntil: answer == MealDecisionDemoAnswer.deferMeal
            ? clock.now().add(Duration(minutes: minutes))
            : null,
      ),
    };
    return true;
  }

  bool acknowledge(String key, String id) {
    final current = state[key];
    if (current == null ||
        current.id != id ||
        current.status != MealDecisionDemoStatus.answered) {
      return false;
    }
    state = {
      ...state,
      key: current.withStatus(
        MealDecisionDemoStatus.accepted,
        acceptedAdvice: current.answer?.decision == null
            ? null
            : MealAdvice(
                current.answer!.decision,
                current.answer == MealDecisionDemoAnswer.insulinThenWait
                    ? WaitSuggestion(
                        current.waitMinutes,
                        current.waitMinutes,
                        current.waitMinutes,
                      )
                    : null,
                source: 'caregiver',
                caregiverId: current.caregiverId,
              ),
      ),
    };
    return true;
  }
}
