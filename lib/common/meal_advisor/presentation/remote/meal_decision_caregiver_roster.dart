import 'package:flutter/material.dart';

import '../../../l10n/language.dart';
import '../../remote/meal_decision_remote_request.dart';

class MealDecisionCaregiverRoster extends StatelessWidget {
  const MealDecisionCaregiverRoster({super.key, required this.request});
  final MealDecisionRemoteRequest request;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final member in request.members)
        MealDecisionCaregiverStatus(request: request, member: member),
    ],
  );
}

class MealDecisionCaregiverStatus extends StatelessWidget {
  const MealDecisionCaregiverStatus({
    super.key,
    required this.request,
    required this.member,
  });
  final MealDecisionRemoteRequest request;
  final Map<String, dynamic> member;
  @override
  Widget build(BuildContext context) {
    final declined = member['status'] == 'declined';
    final disabled = member['status'] == 'disabled';
    final responded = request.respondingCaregiverUid == member['uid'];
    final claimed = member['uid'] == request.claimedByUid;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        declined
            ? Icons.close
            : disabled
            ? Icons.notifications_off_outlined
            : responded || claimed
            ? Icons.check_circle_outline
            : Icons.schedule,
        color: declined
            ? Theme.of(context).colorScheme.error
            : responded || claimed
            ? Colors.green.shade400
            : null,
      ),
      title: Text(member['displayName'] as String? ?? ''),
      subtitle: Text(
        declined
            ? context.lang.mealDecisionRemoteDeclined
            : disabled
            ? context.lang.mealDecisionRemoteDisabled
            : responded
            ? context.lang.mealDecisionRemoteResponded
            : !claimed
            ? context.lang.mealDecisionRemotePending
            : !request.present
            ? context.lang.mealDecisionRemoteAway
            : request.stage == 'decision'
            ? context.lang.mealDecisionRemoteDecision
            : context.lang.mealDecisionRemoteContext,
      ),
    );
  }
}
