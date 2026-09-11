import '../database_impl.dart';
import '../models/wizard_identity_conflict.dart';

void validateWizardIdentity(
  BolusWizardData stored,
  BolusWizardCompanion incoming, {
  bool allowUnidentifiedUpdate = false,
}) {
  if (incoming.localId.present && incoming.localId.value != stored.localId) {
    throw WizardIdentityConflict('Conflicting local wizard identities');
  }
  final oldId = stored.nightscoutId;
  final newId = incoming.nightscoutId.present
      ? incoming.nightscoutId.value
      : null;
  if (oldId != null && newId != null && oldId != newId) {
    throw WizardIdentityConflict(
      'Conflicting Nightscout identities for a wizard timestamp',
    );
  }
  final newSource = incoming.remoteSource.present
      ? incoming.remoteSource.value
      : null;
  if (stored.remoteSource != null &&
      newSource != null &&
      stored.remoteSource != newSource) {
    throw WizardIdentityConflict(
      'Conflicting Nightscout sources for a wizard timestamp',
    );
  }
  final sameRemote = oldId != null && oldId == newId;
  final sameUnidentifiedSource =
      oldId == null && newId == null && stored.source == incoming.source.value;
  final sameLocal =
      incoming.localId.present && incoming.localId.value == stored.localId;
  if (!sameRemote &&
      !sameLocal &&
      !(allowUnidentifiedUpdate && sameUnidentifiedSource)) {
    var compared = false;
    for (final pair in [
      (stored.carbs, incoming.carbs),
      (stored.insulin, incoming.insulin),
    ]) {
      final previous = pair.$1;
      final next = pair.$2.present ? pair.$2.value : null;
      if (previous == null || next == null) continue;
      compared = true;
      if (!previous.isFinite ||
          !next.isFinite ||
          (previous - next).abs() > 0.001) {
        throw WizardIdentityConflict(
          'Conflicting calculator values for a wizard timestamp',
        );
      }
    }
    if (!compared) {
      throw WizardIdentityConflict(
        'Insufficient evidence to merge wizard identities',
      );
    }
  }
}
