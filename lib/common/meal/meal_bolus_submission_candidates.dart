import '../../core/domain/model/bolus_wizard.dart';
import '../../core/domain/model/treatment_base.dart';

/// A retry belongs to the same wait, but keeps its own delivery identity.
/// Prefer the earliest eligible confirmed submission so a later partial entry
/// does not hide an earlier part of the meal.
List<BolusWizard> mealBolusSubmissionCandidates(
  BolusWizard requested,
  Iterable<Treatment> records, {
  bool Function(BolusWizard)? acceptsWizard,
}) =>
    records
        .whereType<BolusWizard>()
        .where(
          (wizard) =>
              wizard.isValid &&
              !wizard.createdAt.isBefore(requested.createdAt) &&
              (acceptsWizard?.call(wizard) ?? true),
        )
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
