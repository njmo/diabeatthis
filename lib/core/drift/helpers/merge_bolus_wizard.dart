import 'package:drift/drift.dart';

import '../database_impl.dart';
import 'validate_wizard_identity.dart';

/// External nulls mean unavailable data, not an instruction to erase a value.
/// Explicit zero/false values remain valid corrections.
Insertable<BolusWizardData> mergeBolusWizard(
  BolusWizardData stored,
  BolusWizardCompanion incoming,
) {
  validateWizardIdentity(stored, incoming, allowUnidentifiedUpdate: true);
  final incomingId = incoming.nightscoutId.present
      ? incoming.nightscoutId.value
      : null;
  final incomingSource = incoming.remoteSource.present
      ? incoming.remoteSource.value
      : null;
  final remoteId = incomingId ?? stored.nightscoutId;

  // A source may qualify an ID only when both arrived together, or when
  // that exact ID already had a source. Never join unrelated partial pairs.
  var remoteSource = stored.remoteSource;
  if (incomingId != null) {
    remoteSource = incomingSource;
    if (remoteSource == null && incomingId == stored.nightscoutId) {
      remoteSource = stored.remoteSource;
    }
  } else if (stored.nightscoutId == null) {
    remoteSource = incomingSource ?? stored.remoteSource;
  }
  final columns = incoming
      .copyWith(
        localId: Value(stored.localId),
        nightscoutId: const Value.absent(),
        remoteSource: const Value.absent(),
      )
      .toColumns(true);
  return RawValuesInsertable({
    for (final entry in columns.entries)
      if (entry.value is! Variable || (entry.value as Variable).value != null)
        entry.key: entry.value,
    // Explicit null here prevents a source-only row from lending its source
    // to a later ID-only record.
    ...BolusWizardCompanion(
      nightscoutId: Value(remoteId),
      remoteSource: Value(remoteSource),
    ).toColumns(true),
  });
}
