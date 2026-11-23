import '../../core/domain/model/bolus_wizard.dart' as domain;
import '../../core/domain/model/manual_bolus.dart';
import '../../core/domain/model/treatment_base.dart';
import '../history/bolus_wizard_grouping.dart';

const mealBolusDeliveryWindow = Duration(minutes: 2);

bool mealBolusDeliveryFollowsWizard(
  domain.BolusWizard wizard,
  ManualBolus delivery,
) {
  final elapsed = delivery.createdAt.difference(wizard.createdAt);
  return wizard.isValid &&
      !elapsed.isNegative &&
      elapsed <= mealBolusDeliveryWindow &&
      (elapsed <= BolusWizardGrouping.carbSubmissionWindow ||
          (wizard.insulin.isFinite &&
              wizard.insulin > 0 &&
              delivery.insulin <= wizard.insulin + 0.001));
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
  final after =
      deliveries.values
          .where(
            (delivery) =>
                delivery.insulin.isFinite &&
                delivery.insulin > 0 &&
                !delivery.createdAt.isBefore(current.createdAt),
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  final nearby = after
      .where(
        (delivery) =>
            delivery.isValid &&
            delivery.createdAt.difference(current.createdAt) <=
                BolusWizardGrouping.carbSubmissionWindow,
      )
      .toList();
  if (nearby.length > 1) return null;
  final delivery = nearby.singleOrNull ?? after.firstOrNull;
  if (delivery == null ||
      !delivery.isValid ||
      !mealBolusDeliveryFollowsWizard(current, delivery)) {
    return null;
  }
  final delayed =
      delivery.createdAt.difference(current.createdAt) >
      BolusWizardGrouping.carbSubmissionWindow;
  if (delayed) {
    if (current.hasUnresolvedDelivery ||
        calculators.values.any(
          (other) =>
              other.createdAt.isAfter(current.createdAt) &&
              !other.createdAt.isAfter(delivery.createdAt),
        )) {
      return null;
    }
  } else if (calculators.values.any(
    (other) =>
        !other.createdAt.isAtSameMomentAs(current.createdAt) &&
        delivery.createdAt.difference(other.createdAt) <=
            BolusWizardGrouping.carbSubmissionWindow &&
        mealBolusDeliveryFollowsWizard(other, delivery),
  )) {
    return null;
  }
  return delivery;
}
