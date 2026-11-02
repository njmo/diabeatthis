import '../../core/domain/model/bolus_wizard.dart';
import '../../core/domain/model/manual_bolus.dart';
import '../history/bolus_wizard_grouping.dart';

enum CalculatorSubmissionStatus {
  awaitingDeliveryConfirmation,
  deliveryConfirmed,
  completedWithoutInsulin,
}

/// One calculator submission and its independently reported insulin delivery.
class CalculatorSubmission {
  const CalculatorSubmission({
    required this.wizard,
    this.delivery,
    this.hasUnresolvedDelivery = false,
  });

  final BolusWizard wizard;
  final ManualBolus? delivery;
  final bool hasUnresolvedDelivery;

  // The local mirror uses this timestamp as the stable submission identity;
  // remote/local identifiers may be enriched by later synchronization.
  DateTime get key => wizard.createdAt;
  double get carbs => wizard.carbs;
  double get recommendedInsulin => wizard.insulin;
  double? get deliveredInsulin =>
      status == CalculatorSubmissionStatus.deliveryConfirmed
      ? delivery!.insulin
      : null;
  bool get isValid => wizard.isValid;
  bool get isComplete =>
      status != CalculatorSubmissionStatus.awaitingDeliveryConfirmation;

  CalculatorSubmissionStatus get status {
    if (!wizard.isValid) {
      return CalculatorSubmissionStatus.awaitingDeliveryConfirmation;
    }
    if (delivery != null &&
        delivery!.isValid &&
        delivery!.insulin.isFinite &&
        delivery!.insulin > 0) {
      return CalculatorSubmissionStatus.deliveryConfirmed;
    }
    final component = wizard.carbohydrateRecord;
    if (!hasUnresolvedDelivery &&
        !wizard.hasUnresolvedDelivery &&
        delivery == null &&
        wizard.calculatorResult?.totalInsulin == 0 &&
        wizard.carbs.isFinite &&
        wizard.carbs > 0 &&
        component != null &&
        component.isValid &&
        (component.carbs - wizard.carbs).abs() <= 0.001 &&
        component.createdAt.difference(wizard.createdAt).abs() <=
            BolusWizardGrouping.carbSubmissionWindow) {
      return CalculatorSubmissionStatus.completedWithoutInsulin;
    }
    return CalculatorSubmissionStatus.awaitingDeliveryConfirmation;
  }

  @override
  bool operator ==(Object other) =>
      other is CalculatorSubmission &&
      wizard == other.wizard &&
      delivery == other.delivery &&
      hasUnresolvedDelivery == other.hasUnresolvedDelivery;

  @override
  int get hashCode => Object.hash(wizard, delivery, hasUnresolvedDelivery);
}
