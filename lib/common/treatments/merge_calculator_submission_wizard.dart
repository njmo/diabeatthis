import '../../core/domain/model/bolus_wizard.dart';

/// Mirrors persisted identity rules without inventing a source/ID pairing.
BolusWizard? mergeCalculatorSubmissionWizard(
  BolusWizard stored,
  BolusWizard incoming,
) {
  if ((stored.localId != null &&
          incoming.localId != null &&
          stored.localId != incoming.localId) ||
      (stored.nightscoutObjectId != null &&
          incoming.nightscoutObjectId != null &&
          stored.nightscoutObjectId != incoming.nightscoutObjectId) ||
      (stored.remoteSource != null &&
          incoming.remoteSource != null &&
          stored.remoteSource != incoming.remoteSource)) {
    return null;
  }
  final sameRemote =
      stored.nightscoutObjectId != null &&
      stored.nightscoutObjectId == incoming.nightscoutObjectId;
  final sameLocal =
      stored.localId != null && stored.localId == incoming.localId;
  final bothUnidentified =
      stored.nightscoutObjectId == null && incoming.nightscoutObjectId == null;
  if (!sameRemote && !sameLocal && !bothUnidentified) {
    var compared = false;
    for (final pair in [
      (stored.calculatorResult?.carbs, incoming.calculatorResult?.carbs),
      (
        stored.calculatorResult?.totalInsulin,
        incoming.calculatorResult?.totalInsulin,
      ),
    ]) {
      final previous = pair.$1;
      final next = pair.$2;
      if (previous == null || next == null) continue;
      compared = true;
      if (!previous.isFinite ||
          !next.isFinite ||
          (previous - next).abs() > 0.001) {
        return null;
      }
    }
    if (!compared) return null;
  }
  var remoteSource = stored.remoteSource;
  if (incoming.nightscoutObjectId != null) {
    remoteSource = incoming.remoteSource;
    if (remoteSource == null && sameRemote) remoteSource = stored.remoteSource;
  } else if (stored.nightscoutObjectId == null) {
    remoteSource = incoming.remoteSource ?? stored.remoteSource;
  }
  return incoming.copyWith(
    hasUnresolvedDelivery:
        stored.hasUnresolvedDelivery || incoming.hasUnresolvedDelivery,
    localId: incoming.localId ?? stored.localId,
    nightscoutObjectId:
        incoming.nightscoutObjectId ?? stored.nightscoutObjectId,
    remoteSource: remoteSource,
  );
}
