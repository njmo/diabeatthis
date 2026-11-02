import 'package:diabeatthis/core/data_sources/domain/treatments_history_repository.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';

class CallbackTreatmentsHistoryRepository
    implements TreatmentsHistoryRepository {
  CallbackTreatmentsHistoryRepository(this.load);

  final Future<List<Treatment>> Function(DateTime, DateTime) load;

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) => load(start, end);

  @override
  Future<TemporaryTarget?> fetchLastTemporaryTarget() async => null;
}
