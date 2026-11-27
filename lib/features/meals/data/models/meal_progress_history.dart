import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../../core/domain/model/extended_carb.dart';

/// Treatment history around a meal that has not been eaten yet: what the
/// child already entered in AAPS for it.
class MealProgressHistory {
  const MealProgressHistory({
    required this.calculators,
    required this.extendedCarbs,
  });

  /// Valid calculator entries with carbohydrates, oldest first.
  final List<BolusWizard> calculators;

  /// Valid eCarbs records, oldest start first.
  final List<ExtendedCarb> extendedCarbs;
}
