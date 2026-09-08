import '../../domain/model/stress_event_treatment.dart';
import '../../domain/model/temporary_target.dart';
import '../../domain/model/treatment_base.dart';
import '../domain/treatments_history_repository.dart';
import 'stress_event_repository.dart';

class StressTreatmentsHistoryRepository implements TreatmentsHistoryRepository {
  const StressTreatmentsHistoryRepository(this.delegate, this.events);

  final TreatmentsHistoryRepository delegate;
  final StressEventRepository events;

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final treatments = await delegate.fetchTreatmentsBetween(start, end);
    final recorded = await events.between(start, end);
    return [...treatments, ...recorded.map(StressEventTreatment.new)]
      ..sort((a, b) => (a.createdAt ?? start).compareTo(b.createdAt ?? start));
  }

  @override
  Future<TemporaryTarget?> fetchLastTemporaryTarget() =>
      delegate.fetchLastTemporaryTarget();
}
