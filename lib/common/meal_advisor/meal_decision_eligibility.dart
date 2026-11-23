import '../app_mode/application_device_mode.dart';
import '../family/family_pairing_member.dart';
import '../family/family_status.dart';
import 'meal_decision_preferences.dart';

/// Family status must be a resolved server value for the signed-in account.
bool mealDecisionFamilyPaired(
  ApplicationDeviceMode mode,
  FamilyStatus? status,
) {
  if (status == null) return false;
  return status.members.any(
    (member) => mode == ApplicationDeviceMode.patient
        ? const {
            FamilyMemberRole.caregiver,
            FamilyMemberRole.managingCaregiver,
          }.contains(member.role)
        : member.role == FamilyMemberRole.child,
  );
}

bool mealDecisionEnabled(
  ApplicationDeviceMode mode,
  MealDecisionPreferences preferences,
) =>
    mode == ApplicationDeviceMode.patient ||
    preferences.caregiverResponsesEnabled;
