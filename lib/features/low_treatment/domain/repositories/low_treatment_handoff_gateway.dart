import '../../../../core/domain/model/treat.dart';
import '../models/low_treatment_handoff_match.dart';
import '../models/low_treatment_handoff_pending.dart';

abstract interface class LowTreatmentHandoffGateway {
  Future<void> register({
    required int mealId,
    required DateTime savedAt,
    required double expectedCarbs,
    required DateTime? suggestionAt,
  });

  Future<bool> hasPending();
  Future<List<LowTreatmentHandoffPending>> loadPending();
  Future<List<LowTreatmentHandoffMatch>> reconcile(
    List<Treat> treatments,
    DateTime now,
  );
  Future<void> markCompleted(int mealId);
  Future<void> discardSavedBefore(DateTime cutoff);
}
