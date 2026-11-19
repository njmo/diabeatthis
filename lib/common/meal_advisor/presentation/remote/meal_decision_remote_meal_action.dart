import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../l10n/language.dart';
import '../../meal_decision_preferences_provider.dart';
import '../../remote/caregiver_meal_decision_eligibility.dart';
import '../../remote/meal_decision_remote_controller.dart';
import 'caregiver_meal_decision_sheet.dart';
import 'meal_decision_answered_status.dart';

/// The same request is accessible from its meal card and from the inbox/push.
class MealDecisionRemoteMealAction extends HookConsumerWidget {
  const MealDecisionRemoteMealAction({super.key, required this.mealId});
  final int mealId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inbox = ref.watch(mealDecisionRemoteControllerProvider);
    final request = inbox.latestForMeal(mealId);
    final deadlineTick = useState(0);
    useEffect(() {
      if (request == null) return null;
      final remaining = request.deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) return null;
      final timer = Timer(
        remaining + const Duration(milliseconds: 1),
        () => deadlineTick.value++,
      );
      return timer.cancel;
    }, [request?.id, request?.deadline]);

    if (!ref.watch(mealDecisionPreferencesProvider).caregiverResponsesEnabled) {
      return const SizedBox.shrink();
    }
    if (Firebase.apps.isNotEmpty &&
        inbox.accountUid != FirebaseAuth.instance.currentUser?.uid) {
      return const SizedBox.shrink();
    }

    final now = DateTime.now();

    if (request != null) {
      if (request.timedOutAt(now)) {
        return const MealDecisionAnsweredStatus(isTimedOut: true);
      }

      if (request.status == 'answered' ||
          request.status == 'accepting' ||
          request.status == 'accepted' ||
          request.decision != null) {
        return MealDecisionAnsweredStatus(
          answer: request.answer,
          minutes: request.minutes,
          message: request.message,
          caregiverName: request.respondingCaregiverName,
          isAccepted: request.status == 'accepted',
        );
      }

      if (request.pending) {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        final taken =
            request.status == 'waiting' &&
            request.claimedByUid != null &&
            request.claimedByUid != uid &&
            !request.claimAvailable;

        final memberStatus = caregiverMealDecisionMemberStatus(request, uid);
        if (memberStatus == 'declined' || memberStatus == 'disabled') {
          return Text(
            memberStatus == 'declined'
                ? context.lang.mealDecisionRemoteDeclined
                : context.lang.mealDecisionRemoteDisabled,
          );
        }
        if (taken) {
          final name = request.claimedByName?.trim();
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  name == null || name.isEmpty
                      ? context.lang.mealDecisionRemoteAlreadyTaken
                      : context.lang.mealDecisionClaimedBy(name),
                ),
              ),
            ],
          );
        }
        return FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () =>
              showCaregiverMealDecisionRequest(context, request.id),
          icon: const Icon(Icons.mark_chat_unread_outlined, size: 16),
          label: Text(context.lang.mealDecisionRemoteYourDecision),
        );
      }
    }

    return const SizedBox.shrink();
  }
}
