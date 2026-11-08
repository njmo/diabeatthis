import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_controller.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.fromMillisecondsSinceEpoch(5000);
  MealDecisionRemoteRequest request(
    String status, {
    String? reason,
    bool aborted = false,
    int? completedAt,
    int created = 1000,
  }) => MealDecisionRemoteRequest({
    'id': '$created',
    'mealId': '1',
    'ownerUid': 'child',
    'sourceId': 'source',
    'status': status,
    'createdAt': created,
    'deadline': 4000,
    if (reason != null) 'terminalReason': reason,
    if (aborted) 'acceptanceAborted': true,
    if (completedAt != null) 'completedAt': completedAt,
  });

  test('distinguishes timeout from early decline, aborted and accepted', () {
    expect(request('waiting').timedOutAt(now), isTrue);
    expect(request('expired').timedOutAt(now), isTrue);
    expect(
      request('expired', reason: 'allCaregiversDeclined').timedOutAt(now),
      isFalse,
    );
    expect(request('expired', aborted: true).timedOutAt(now), isFalse);
    expect(
      request('expired', aborted: true, completedAt: 3999).timedOutAt(now),
      isFalse,
    );
    expect(
      request('expired', aborted: true, completedAt: 4000).timedOutAt(now),
      isTrue,
    );
    expect(request('accepted').timedOutAt(now), isFalse);
    expect(request('accepting').timedOutAt(now), isFalse);
    expect(
      request('waiting').timedOutAt(DateTime.fromMillisecondsSinceEpoch(3999)),
      isFalse,
    );
  });
  test('newer request takes precedence over an older timeout', () {
    final old = request('expired');
    final recent = request('waiting', created: 2000);
    expect(
      MealDecisionRemoteInbox(requests: [old, recent]).latestForMeal(1),
      same(recent),
    );
  });
}
