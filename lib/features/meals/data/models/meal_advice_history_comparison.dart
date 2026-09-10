import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../../core/domain/model/manual_bolus.dart';
import '../../../../core/domain/model/treatment_base.dart';
import 'meal_analysis_data.dart';

/// Window membership is not proof that a treatment belongs to this meal.
class MealAdviceHistoryComparison {
  final MealAnalysisData analysis;
  const MealAdviceHistoryComparison(this.analysis);

  bool contains(Treatment treatment) {
    final at = treatment.createdAt;
    return treatment.isValid &&
        at != null &&
        !at.isBefore(analysis.eventStart) &&
        !at.isAfter(analysis.eventEnd);
  }

  List<BolusWizard> get wizards => List.unmodifiable(
    analysis.treatments.whereType<BolusWizard>().where(contains).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
  );

  List<ManualBolus> get deliveries => List.unmodifiable(
    analysis.treatments
        .whereType<ManualBolus>()
        .where((t) => contains(t) && t.insulin.isFinite && t.insulin > 0)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
  );

  InsulinBolusSummary get insulin => InsulinBolusSummary.fromTreatments(
    treatments: analysis.treatments,
    start: analysis.eventStart,
    end: analysis.eventEnd,
  );
}
