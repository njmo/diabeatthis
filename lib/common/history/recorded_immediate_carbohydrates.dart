import '../../core/domain/model/bolus_wizard.dart';
import '../../core/domain/model/treat.dart';
import '../../core/domain/model/treatment_base.dart';
import 'immediate_carbohydrate.dart';

/// Actual carbohydrate entries, excluding calculator estimates and duplicate
/// embedded components when the same recorded entry is already present.
List<Treat> recordedImmediateCarbohydrates(Iterable<Treatment> treatments) {
  final entries = <Treat>[
    for (final treatment in treatments)
      if (immediateCarbohydrate(treatment) case final Treat entry)
        if (entry.isValid && entry.carbs > 0) entry,
  ];
  bool alreadyRecorded(Treat component) => entries.any(
    (entry) =>
        identical(entry, component) ||
        (entry.externalId != null &&
            component.externalId != null &&
            entry.externalId == component.externalId),
  );
  for (final wizard in treatments.whereType<BolusWizard>()) {
    final component = wizard.carbohydrateRecord;
    if (wizard.isValid &&
        component != null &&
        component.isValid &&
        component.carbs > 0 &&
        !alreadyRecorded(component)) {
      entries.add(component);
    }
  }
  return entries..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}
