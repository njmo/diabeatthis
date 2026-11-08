import 'meal_decision_remote_request.dart';

String? caregiverMealDecisionMemberStatus(
  MealDecisionRemoteRequest request,
  String? uid,
) =>
    request.members
            .where((member) => member['uid'] == uid)
            .firstOrNull?['status']
        as String?;

bool caregiverCanOpenMealDecision(
  MealDecisionRemoteRequest request,
  String? uid,
) {
  if (uid == null || !request.pending || request.status != 'waiting') {
    return false;
  }
  final status = caregiverMealDecisionMemberStatus(request, uid);
  return const {'available', 'claimed'}.contains(status) &&
      (request.claimAvailable || request.claimedByUid == uid);
}

/// Mirrors server delegation requirements without treating a stale roster as authority.
List<Map<String, dynamic>> mealDecisionDelegateCandidates(
  MealDecisionRemoteRequest request,
  String? uid,
) {
  if (!caregiverCanOpenMealDecision(request, uid)) return const [];
  return request.members
      .where(
        (member) =>
            member['uid'] is String &&
            member['uid'] != uid &&
            member['enabled'] == true &&
            !const {'declined', 'disabled'}.contains(member['status']),
      )
      .toList();
}
