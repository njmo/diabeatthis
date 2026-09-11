/// Refuses an ambiguous merge without exposing medical values in logs.
class WizardIdentityConflict extends StateError {
  WizardIdentityConflict(super.message);
}
