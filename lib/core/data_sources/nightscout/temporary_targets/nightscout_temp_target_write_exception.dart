/// Timeouts, conflicts and server failures can follow an accepted treatment.
class NightscoutTempTargetWriteException extends StateError {
  NightscoutTempTargetWriteException(this.statusCode)
    : super('Nightscout rejected temporary target ($statusCode)');

  final int statusCode;

  bool get isDefinitiveRejection =>
      statusCode >= 400 &&
      statusCode < 500 &&
      statusCode != 408 &&
      statusCode != 409;
}
