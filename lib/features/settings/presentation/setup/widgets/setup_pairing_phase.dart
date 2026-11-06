enum SetupPairingPhase { invitation, success, compact }

abstract final class SetupPairingTiming {
  static const successHold = Duration(milliseconds: 500);
  static const collapse = Duration(milliseconds: 240);
}
