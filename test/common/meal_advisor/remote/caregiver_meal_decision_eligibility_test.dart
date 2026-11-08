import 'package:diabeatthis/common/meal_advisor/remote/caregiver_meal_decision_eligibility.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_request.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MealDecisionRemoteRequest request(
    String status, {
    String? owner,
    bool available = true,
  }) => MealDecisionRemoteRequest({
    'status': 'waiting',
    'deadline': DateTime.now()
        .add(const Duration(minutes: 5))
        .millisecondsSinceEpoch,
    'claimedByUid': owner,
    'claimAvailable': available,
    'claimUntil': DateTime.now()
        .add(const Duration(minutes: 1))
        .millisecondsSinceEpoch,
    'members': [
      {'uid': 'me', 'status': status},
    ],
  });

  test(
    'only eligible caregivers can open an available or delegated request',
    () {
      expect(caregiverCanOpenMealDecision(request('available'), 'me'), isTrue);
      expect(
        caregiverCanOpenMealDecision(
          request('claimed', owner: 'me', available: false),
          'me',
        ),
        isTrue,
      );
      expect(
        caregiverCanOpenMealDecision(
          request('available', owner: 'other', available: false),
          'me',
        ),
        isFalse,
      );
      expect(caregiverCanOpenMealDecision(request('declined'), 'me'), isFalse);
      expect(caregiverCanOpenMealDecision(request('disabled'), 'me'), isFalse);
      expect(
        caregiverCanOpenMealDecision(request('available'), 'stranger'),
        isFalse,
      );
    },
  );
}
