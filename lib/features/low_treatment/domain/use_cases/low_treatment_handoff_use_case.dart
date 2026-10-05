import '../../../../common/history/bolus_wizard_grouping.dart';
import '../../../../core/data_sources/domain/treatments_history_repository.dart';
import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../../core/domain/model/treat.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../../../../core/logger/logger.dart';
import '../models/low_treatment_handoff_match.dart';
import '../repositories/low_treatment_handoff_gateway.dart';

class LowTreatmentHandoffUseCase with Logging {
  final LowTreatmentHandoffGateway handoffs;
  final Future<double?> Function(int mealId) loadRecordedCarbs;
  final Future<TreatmentsHistoryRepository> Function() loadHistory;

  const LowTreatmentHandoffUseCase({
    required this.handoffs,
    required this.loadRecordedCarbs,
    required this.loadHistory,
  });

  Future<void> registerPending({
    required int mealId,
    required DateTime savedAt,
    required DateTime? suggestionAt,
  }) async {
    final carbs = await loadRecordedCarbs(mealId);
    if (carbs == null || !carbs.isFinite || carbs <= 0) {
      throw StateError('Recorded carbohydrate amount required');
    }
    await handoffs.register(
      mealId: mealId,
      savedAt: savedAt,
      expectedCarbs: carbs,
      suggestionAt: suggestionAt,
    );
  }

  Future<bool> hasPending() => handoffs.hasPending();

  Future<List<LowTreatmentHandoffMatch>> reconcile({
    required DateTime now,
    List<Treatment> liveTreatments = const [],
  }) async {
    await handoffs.discardSavedBefore(now.subtract(const Duration(hours: 24)));
    final pending = await handoffs.loadPending();
    if (pending.isEmpty) return const [];
    final unmatched = pending
        .where((item) => item.matchedTreatAt == null)
        .toList();
    if (unmatched.isEmpty) return handoffs.reconcile(const [], now);
    final treatments = <Treatment>[...liveTreatments];
    const neighbourWindow = BolusWizardGrouping.carbSubmissionWindow;
    final settledAfter = neighbourWindow + const Duration(milliseconds: 1);
    try {
      final history = await loadHistory().timeout(const Duration(seconds: 2));
      // One bounded read preserves calculator neighbours and overlapping handoffs.
      final start = unmatched
          .map((item) => item.savedAt)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      final last = unmatched
          .map((item) => item.savedAt)
          .reduce((a, b) => a.isAfter(b) ? a : b);
      final requestedEnd = last.add(const Duration(minutes: 5) + settledAfter);
      final end = requestedEnd.isAfter(now) ? now : requestedEnd;
      if (!start.isAfter(now)) {
        treatments.addAll(
          await history
              .fetchTreatmentsBetween(start.subtract(neighbourWindow), end)
              .timeout(const Duration(seconds: 2)),
        );
      }
    } catch (error) {
      logW('Low treatment history unavailable: ${error.runtimeType}');
      // Already persisted matches must remain deliverable when history is offline.
      // Live batches can still be reconciled without a local mirror.
    }
    // Local and remote copies must not hide calculator neighbours as duplicates.
    final canonical = <Object, Treatment>{};
    for (final item in treatments) {
      final key = switch (item) {
        Treat() => (Treat, item.createdAt, item.carbs, item.isValid),
        BolusWizard() => (
          BolusWizard,
          item.createdAt,
          item.carbs,
          item.insulin,
          item.isValid,
        ),
        _ => item,
      };
      canonical.putIfAbsent(key, () => item);
    }
    final groups = BolusWizardGrouping(canonical.values);
    final mealCarbTimes = canonical.values
        .whereType<Treat>()
        .where(groups.isRelated)
        .map((item) => item.createdAt)
        .toSet();
    final treats = treatments
        .whereType<Treat>()
        .where(
          (item) =>
              !mealCarbTimes.contains(item.createdAt) &&
              // Wait for the calculator's neighbouring record before confirming live carbs.
              !item.createdAt.add(settledAfter).isAfter(now),
        )
        .toList();
    return handoffs.reconcile(treats, now);
  }

  Future<void> markCompleted(int mealId) => handoffs.markCompleted(mealId);
}
