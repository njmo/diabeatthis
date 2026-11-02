import '../../core/domain/model/bolus_wizard.dart';
import '../../core/domain/model/manual_bolus.dart';
import '../../core/domain/model/treat.dart';
import '../../core/domain/model/treatment_base.dart';

/// Groups chronological calculator neighbours without deleting raw data.
class BolusWizardGrouping {
  // This matches records from one calculator submission, not the meal window.
  // Keep uncertain carbohydrates visible rather than hiding a separate intake.
  static const carbSubmissionWindow = Duration(seconds: 10);
  static const deliveryClockTolerance = Duration(seconds: 1);

  final Set<Treatment> relatedRecords;

  /// Preserves the calculator provenance of each recognized carbohydrate record.
  final Map<Treat, BolusWizard> carbohydrateWizards;

  BolusWizardGrouping(Iterable<Treatment> treatments)
    : relatedRecords = <Treatment>{},
      carbohydrateWizards = <Treat, BolusWizard>{} {
    final input = treatments.toList();
    final explicitCarbTimes = input
        .whereType<Treat>()
        .map((record) => record.createdAt.millisecondsSinceEpoch)
        .toSet();
    // Persisted components remain grouping evidence, while never being exposed
    // by history as independent intakes. Explicit updates take precedence.
    input.addAll([
      for (final wizard in input.whereType<BolusWizard>())
        if (wizard.carbohydrateRecord case final Treat component)
          if (!explicitCarbTimes.contains(
            component.createdAt.millisecondsSinceEpoch,
          ))
            component,
    ]);
    final timestampGroups = <int, List<Treatment>>{};
    for (final record in input) {
      final time = record.createdAt;
      if (time != null) {
        timestampGroups
            .putIfAbsent(time.millisecondsSinceEpoch, () => [])
            .add(record);
      }
    }
    final ambiguous = <Treatment>{};
    for (final group in timestampGroups.values) {
      if (group.length <= 1) continue;
      final types = group.map(_submissionOrder).toSet();
      if (types.contains(3) || types.length != group.length) {
        ambiguous.addAll(group);
      }
    }
    final records = timestampGroups.values.expand((group) => group).toList()
      ..sort((a, b) {
        final timeOrder = a.createdAt!.compareTo(b.createdAt!);
        return timeOrder != 0
            ? timeOrder
            : _submissionOrder(a).compareTo(_submissionOrder(b));
      });
    for (var index = 0; index < records.length; index++) {
      final wizard = records[index];
      if (wizard is! BolusWizard ||
          !wizard.isValid ||
          ambiguous.contains(wizard)) {
        continue;
      }
      final previous = index > 0 ? records[index - 1] : null;
      final next = index + 1 < records.length ? records[index + 1] : null;
      var hasLeadingCarbs = false;
      if (previous is Treat &&
          !ambiguous.contains(previous) &&
          wizard.createdAt.difference(previous.createdAt) <=
              carbSubmissionWindow) {
        hasLeadingCarbs = _match(
          previous,
          wizard.carbs,
          previous.carbs.toDouble(),
        );
        if (hasLeadingCarbs) {
          carbohydrateWizards.putIfAbsent(previous, () => wizard);
        }
      }
      if (next is ManualBolus && !ambiguous.contains(next)) {
        _match(next, wizard.insulin, next.insulin);
      }
      if (!hasLeadingCarbs && previous is ManualBolus && index >= 2) {
        final carbs = records[index - 2];
        // Some AAPS submissions timestamp the delivery a few milliseconds
        // before the calculator. Require the complete matching leading pair.
        if (carbs is Treat &&
            !ambiguous.contains(carbs) &&
            !ambiguous.contains(previous) &&
            wizard.createdAt.difference(previous.createdAt) <=
                deliveryClockTolerance &&
            wizard.createdAt.difference(carbs.createdAt) <=
                carbSubmissionWindow &&
            previous.isValid &&
            previous.insulin.isFinite &&
            previous.insulin > 0 &&
            (previous.insulin - wizard.insulin).abs() <= 0.001) {
          hasLeadingCarbs = _match(carbs, wizard.carbs, carbs.carbs.toDouble());
          if (hasLeadingCarbs) {
            carbohydrateWizards.putIfAbsent(carbs, () => wizard);
            _match(previous, wizard.insulin, previous.insulin);
          }
        }
      }
      // AAPS also records explicit zero-insulin calculator submissions as a
      // calculator followed by carbohydrates, without an insulin record.
      // Missing calculator insulin is unknown and must not use the getter's zero fallback.
      if (!hasLeadingCarbs &&
          wizard.calculatorResult?.totalInsulin == 0 &&
          next is Treat &&
          !ambiguous.contains(next) &&
          next.createdAt.difference(wizard.createdAt) <= carbSubmissionWindow &&
          _match(next, wizard.carbs, next.carbs.toDouble())) {
        carbohydrateWizards.putIfAbsent(next, () => wizard);
        continue;
      }
      if (!hasLeadingCarbs) {
        _matchTrailingSubmission(records, index, wizard, ambiguous);
      }
    }
  }

  void _matchTrailingSubmission(
    List<Treatment> records,
    int wizardIndex,
    BolusWizard wizard,
    Set<Treatment> ambiguous,
  ) {
    if (wizardIndex + 2 >= records.length) return;
    final first = records[wizardIndex + 1];
    final second = records[wizardIndex + 2];
    // AAPS can publish the calculator before the delivery and carbohydrate pair.
    // Equal-time pairs sort carbohydrates first; other later intakes stay separate.
    final (insulin, carbs) = switch ((first, second)) {
      (ManualBolus insulin, Treat carbs) => (insulin, carbs),
      (Treat carbs, ManualBolus insulin)
          when carbs.createdAt.isAtSameMomentAs(insulin.createdAt) =>
        (insulin, carbs),
      _ => (null, null),
    };
    if (insulin == null ||
        carbs == null ||
        ambiguous.contains(insulin) ||
        ambiguous.contains(carbs) ||
        !insulin.isValid ||
        !insulin.insulin.isFinite ||
        insulin.insulin <= 0 ||
        !insulin.createdAt.isAfter(wizard.createdAt) ||
        carbs.createdAt.difference(wizard.createdAt) > carbSubmissionWindow) {
      return;
    }
    if (_match(carbs, wizard.carbs, carbs.carbs.toDouble())) {
      carbohydrateWizards.putIfAbsent(carbs, () => wizard);
      // The recorded delivery may differ from the calculator recommendation.
      _match(insulin, wizard.insulin, insulin.insulin);
    }
  }

  // Equal timestamps may arrive in different orders from local and remote history.
  static int _submissionOrder(Treatment record) => switch (record) {
    Treat() => 0,
    BolusWizard() => 1,
    ManualBolus() => 2,
    _ => 3,
  };

  bool _match(Treatment record, double expectedAmount, double recordedAmount) {
    // Keep differing amounts visible rather than replacing them with calculator values.
    if (record.isValid &&
        expectedAmount.isFinite &&
        expectedAmount > 0 &&
        recordedAmount.isFinite &&
        (recordedAmount - expectedAmount).abs() <= 0.001) {
      relatedRecords.add(record);
      return true;
    }
    return false;
  }

  bool isRelated(Treatment treatment) => relatedRecords.contains(treatment);
}
