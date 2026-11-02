import '../../core/domain/model/bolus_wizard.dart' as domain;
import '../../core/domain/model/manual_bolus.dart';
import '../../core/domain/model/treatment_base.dart';
import '../history/bolus_wizard_grouping.dart';

bool mealBolusDeliveryFollowsWizard(
  domain.BolusWizard wizard,
  ManualBolus delivery,
) {
  final elapsed = delivery.createdAt.difference(wizard.createdAt);
  final precisionOverlap =
      elapsed >= -BolusWizardGrouping.deliveryClockTolerance &&
      (delivery.insulin - wizard.insulin).abs() <= 0.001;
  return wizard.isValid &&
      (!elapsed.isNegative || precisionOverlap) &&
      elapsed <= BolusWizardGrouping.carbSubmissionWindow;
}

/// Even invalidated or ambiguous positive records rule out a carbs-only
/// completion until their delivery is resolved.
bool hasMealBolusDeliveryEvidence(
  domain.BolusWizard wizard,
  Iterable<Treatment> records,
) => records.whereType<ManualBolus>().any(
  (delivery) =>
      delivery.insulin.isFinite &&
      delivery.insulin > 0 &&
      mealBolusDeliveryFollowsWizard(wizard, delivery),
);

/// Submission timestamps identify the command; arrival may follow minutes later.
/// Calculator recommendations are never used as recorded delivery amounts.
ManualBolus? findMealBolusDelivery(
  domain.BolusWizard wizard,
  Iterable<Treatment> records,
) {
  if (!wizard.isValid) return null;

  final calculators = <int, domain.BolusWizard>{
    wizard.createdAt.millisecondsSinceEpoch: wizard,
  };
  final deliveries = <int, ManualBolus>{};
  for (final record in records) {
    switch (record) {
      case domain.BolusWizard():
        calculators[record.createdAt.millisecondsSinceEpoch] = record;
      case ManualBolus():
        deliveries[record.createdAt.millisecondsSinceEpoch] = record;
      default:
        break;
    }
  }
  final current = calculators[wizard.createdAt.millisecondsSinceEpoch]!;
  if (!current.isValid) return null;
  if ((wizard.nightscoutObjectId != null &&
          current.nightscoutObjectId != null &&
          wizard.nightscoutObjectId != current.nightscoutObjectId) ||
      (wizard.remoteSource != null &&
          current.remoteSource != null &&
          wizard.remoteSource != current.remoteSource) ||
      (wizard.localId != null &&
          current.localId != null &&
          wizard.localId != current.localId)) {
    return null;
  }
  final candidates = deliveries.values
      .where(
        (delivery) =>
            delivery.isValid &&
            delivery.insulin.isFinite &&
            delivery.insulin > 0 &&
            mealBolusDeliveryFollowsWizard(current, delivery),
      )
      .toList();
  if (candidates.length != 1) return null;
  final delivery = candidates.single;
  if (calculators.values
          .where((item) => mealBolusDeliveryFollowsWizard(item, delivery))
          .length !=
      1) {
    return null;
  }
  return delivery;
}
