import '../../core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import '../../core/data_sources/local_mirror/mappers/manual_bolus_drift_mapper.dart';
import '../../core/data_sources/local_mirror/mappers/treat_drift_mapper.dart';
import '../../core/domain/model/bolus_wizard.dart';
import '../../core/domain/model/treat.dart';
import '../../core/domain/model/treatment_base.dart';
import '../../core/drift/database_impl.dart' show DatabaseImpl;
import '../history/bolus_wizard_grouping.dart';
import '../treatments/calculator_submission.dart';
import '../treatments/merge_calculator_submission_wizard.dart';
import 'meal_bolus_delivery.dart';

/// Resolves completion from independently recorded components, retaining
/// invalidations and ambiguity instead of inventing a zero insulin delivery.
CalculatorSubmission resolveMealCalculatorSubmission(
  BolusWizard wizard,
  Iterable<Treatment> records,
) {
  final currentRecords = <(Type, int), Treatment>{};
  final unresolved = <int>{};
  for (final record in [wizard, ...records]) {
    final at = record.createdAt;
    if (record is BolusWizard && record.hasUnresolvedDelivery) {
      unresolved.add(record.createdAt.millisecondsSinceEpoch);
    }
    if (at != null) {
      currentRecords[(record.runtimeType, at.millisecondsSinceEpoch)] = record;
    }
  }
  final record = currentRecords.values.whereType<BolusWizard>().firstWhere(
    (record) =>
        record.createdAt.millisecondsSinceEpoch ==
        wizard.createdAt.millisecondsSinceEpoch,
  );
  final current = record.copyWith(
    hasUnresolvedDelivery: unresolved.contains(
      record.createdAt.millisecondsSinceEpoch,
    ),
  );
  if (mergeCalculatorSubmissionWizard(current, wizard) == null) {
    return CalculatorSubmission(
      wizard: wizard.copyWith(carbohydrateRecord: null),
      hasUnresolvedDelivery: true,
    );
  }
  final components = <int, Treat>{
    for (final record in currentRecords.values.whereType<BolusWizard>())
      if (record.carbohydrateRecord case final Treat component)
        component.createdAt.millisecondsSinceEpoch: component,
    for (final component in currentRecords.values.whereType<Treat>())
      component.createdAt.millisecondsSinceEpoch: component,
  };
  final grouping = BolusWizardGrouping([
    for (final record in currentRecords.values)
      if (record is BolusWizard)
        record.copyWith(carbohydrateRecord: null)
      else if (record is! Treat)
        record,
    ...components.values,
  ]);
  final component = grouping.carbohydrateWizards.entries
      .where(
        (entry) => entry.value.createdAt.isAtSameMomentAs(current.createdAt),
      )
      .firstOrNull
      ?.key;
  final delivery = findMealBolusDelivery(current, currentRecords.values);
  return CalculatorSubmission(
    wizard: current.copyWith(carbohydrateRecord: component),
    delivery: delivery,
    hasUnresolvedDelivery:
        delivery == null &&
        (current.hasUnresolvedDelivery ||
            hasMealBolusDeliveryEvidence(current, currentRecords.values)),
  );
}

Future<CalculatorSubmission> readMealCalculatorSubmission(
  DatabaseImpl db,
  BolusWizard wizard, {
  Iterable<Treatment> liveTreatments = const [],
}) async {
  final margin =
      BolusWizardGrouping.carbSubmissionWindow +
      BolusWizardGrouping.deliveryClockTolerance;
  final start = wizard.createdAt.subtract(margin);
  final end = wizard.createdAt.add(margin);
  final calculators = await db.localMirrorDao.getBolusWizardsBetween(
    start,
    end,
  );
  final deliveries = await db.localMirrorDao.getManualBolusesBetween(
    start,
    end,
  );
  final carbohydrates = await db.localMirrorDao.getTreatsBetween(start, end);
  return resolveMealCalculatorSubmission(wizard, [
    ...calculators.map((row) => row.toDomain()),
    ...deliveries.map((row) => row.toDomain()),
    ...carbohydrates.map((row) => row.toDomain()),
    ...liveTreatments,
  ]);
}
