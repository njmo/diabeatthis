import '../../../../common/meal/calculator/meal_calculator_evidence.dart';
import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../../core/domain/model/extended_carb.dart';
import '../../data/models/meal_details_data.dart';
import '../../data/models/meal_progress_history.dart';
import '../../domain/models/meal_ecarbs_proposal.dart';

const _bolusStatuses = {
  'bolused-waiting',
  'bolused-eating',
  'waited-eating',
  'eaten-bolused',
};

/// Planned eCarbs compared with what AAPS history holds for the meal.
class MealExtendedCarbsProgress {
  const MealExtendedCarbsProgress({
    required this.grams,
    required this.durationMinutes,
    required this.expectedStart,
    required this.entered,
  });

  final int grams;
  final int durationMinutes;

  /// Null until the calculator entry that anchors the schedule is known.
  final DateTime? expectedStart;
  final ExtendedCarb? entered;

  DateTime? get earliestStart =>
      expectedStart?.subtract(extendedCarbsEarlyStartTolerance);
  DateTime? get latestStart =>
      expectedStart?.add(extendedCarbsLateStartTolerance);
}

/// What a meal in progress has done so far and what it still waits for.
class MealProgressNow {
  const MealProgressNow({
    required this.status,
    required this.calculator,
    required this.bolusAt,
    required this.waitStartedAt,
    required this.waitMinutes,
    required this.extendedCarbs,
  });

  factory MealProgressNow.from({
    required MealDetailsData details,
    required MealProgressHistory? history,
    required MealEcarbsProposal proposal,
  }) {
    DateTime? firstAt(bool Function(String status) test) => details
        .statusHistory
        .where((entry) => test(entry.status))
        .map((entry) => entry.createdAt)
        .fold<DateTime?>(
          null,
          (first, at) => first == null || at.isBefore(first) ? at : first,
        );
    final started = firstAt((status) => status != 'planned');
    // The meal's own calculator follows the start of its bolus step.
    final calculator = history?.calculators
        .where(
          (wizard) =>
              started == null ||
              !wizard.createdAt.isBefore(
                started.subtract(const Duration(minutes: 2)),
              ),
        )
        .firstOrNull;
    final bolusAt = firstAt(_bolusStatuses.contains);
    final waitStartedAt = firstAt((status) => status == 'bolused-waiting');
    MealExtendedCarbsProgress? extendedCarbs;
    final grams = proposal.grams;
    final duration = proposal.durationMinutes;
    if (proposal.kind == MealEcarbsProposalKind.extendedCarbs &&
        grams != null &&
        grams > 0 &&
        duration != null) {
      final anchor = calculator?.createdAt ?? bolusAt;
      final delay = proposal.delayMinutes;
      final expected = anchor == null || delay == null
          ? null
          : anchor.add(Duration(minutes: delay));
      final durationMs = Duration(minutes: duration).inMilliseconds;
      final matching = expected == null
          ? const <ExtendedCarb>[]
          : (history?.extendedCarbs ?? const <ExtendedCarb>[])
                .where(
                  (carb) =>
                      carb.duration == durationMs &&
                      extendedCarbsStartMatches(
                        carb.createdAt.millisecondsSinceEpoch,
                        expected.millisecondsSinceEpoch,
                      ),
                )
                .toList();
      // Like the calculator tracker, only the full planned amount counts.
      final enteredGrams = matching.fold<int>(
        0,
        (sum, carb) => sum + carb.carbs,
      );
      final entered = enteredGrams >= grams ? matching.first : null;
      extendedCarbs = MealExtendedCarbsProgress(
        grams: grams,
        durationMinutes: duration,
        expectedStart: expected,
        entered: entered,
      );
    }
    return MealProgressNow(
      status: details.meal.status,
      calculator: calculator,
      bolusAt: bolusAt,
      waitStartedAt: waitStartedAt,
      waitMinutes: waitStartedAt == null
          ? null
          : details.advisorDecision?.initialWaitTime,
      extendedCarbs: extendedCarbs,
    );
  }

  final String status;
  final BolusWizard? calculator;
  final DateTime? bolusAt;
  final DateTime? waitStartedAt;
  final int? waitMinutes;
  final MealExtendedCarbsProgress? extendedCarbs;

  DateTime? get waitEndsAt => waitStartedAt == null || waitMinutes == null
      ? null
      : waitStartedAt!.add(Duration(minutes: waitMinutes!));

  bool get waitsBeforeEating => status == 'bolused-waiting';
}
