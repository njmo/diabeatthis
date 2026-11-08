import 'package:diabeatthis/common/meal_advisor/remote/caregiver_meal_decision_eligibility.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MealDecisionRemoteRequest request(List<Map<String, dynamic>> others) =>
      MealDecisionRemoteRequest({
        'status': 'waiting',
        'deadline': DateTime.now()
            .add(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
        'claimAvailable': true,
        'members': [
          {'uid': 'me', 'status': 'available', 'enabled': true},
          ...others,
        ],
      });

  test('a sole caregiver has no delegation candidates', () {
    expect(mealDecisionDelegateCandidates(request([]), 'me'), isEmpty);
  });

  test('only another enabled caregiver who has not declined is offered', () {
    final value = request([
      {'uid': 'disabled', 'status': 'available', 'enabled': false},
      {'uid': 'declined', 'status': 'declined', 'enabled': true},
      {'uid': 'other', 'status': 'available', 'enabled': true},
    ]);
    expect(mealDecisionDelegateCandidates(value, 'me').map((m) => m['uid']), [
      'other',
    ]);
    expect(mealDecisionDelegateCandidates(value, 'stranger'), isEmpty);
    expect(mealDecisionDelegateCandidates(value, null), isEmpty);
  });
}
