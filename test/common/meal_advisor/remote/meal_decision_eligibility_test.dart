import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/family/family_pairing_member.dart';
import 'package:diabeatthis/common/family/family_status.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_eligibility.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

FamilyPairingMember member(FamilyMemberRole role) => FamilyPairingMember(
  id: 'id',
  displayName: '',
  role: role,
  invitationId: '',
);

void main() {
  test('child can ask on demand while caregivers choose to participate', () {
    expect(
      mealDecisionEnabled(
        ApplicationDeviceMode.patient,
        const MealDecisionPreferences(),
      ),
      isTrue,
    );
    expect(
      mealDecisionEnabled(
        ApplicationDeviceMode.patient,
        const MealDecisionPreferences(method: MealDecisionMethod.caregiver),
      ),
      isTrue,
    );
    expect(
      mealDecisionEnabled(
        ApplicationDeviceMode.caregiver,
        const MealDecisionPreferences(caregiverResponsesEnabled: false),
      ),
      isFalse,
    );
    expect(
      mealDecisionEnabled(
        ApplicationDeviceMode.caregiver,
        const MealDecisionPreferences(caregiverResponsesEnabled: true),
      ),
      isTrue,
    );
  });
  test('pairing requires resolved family with the opposite role', () {
    expect(
      mealDecisionFamilyPaired(ApplicationDeviceMode.patient, null),
      isFalse,
    );
    expect(
      mealDecisionFamilyPaired(
        ApplicationDeviceMode.patient,
        const FamilyStatus(),
      ),
      isFalse,
    );
    expect(
      mealDecisionFamilyPaired(
        ApplicationDeviceMode.patient,
        FamilyStatus(members: [member(FamilyMemberRole.managingCaregiver)]),
      ),
      isTrue,
    );
    expect(
      mealDecisionFamilyPaired(
        ApplicationDeviceMode.caregiver,
        FamilyStatus(members: [member(FamilyMemberRole.child)]),
      ),
      isTrue,
    );
    expect(
      mealDecisionFamilyPaired(
        ApplicationDeviceMode.caregiver,
        FamilyStatus(members: [member(FamilyMemberRole.managingCaregiver)]),
      ),
      isFalse,
    );
  });
}
