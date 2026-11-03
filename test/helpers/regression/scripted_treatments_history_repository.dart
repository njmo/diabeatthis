import 'package:diabeatthis/core/data_sources/domain/treatments_history_repository.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedTreatmentsHistoryRepository extends Fake
    implements TreatmentsHistoryRepository {
  final ScriptedRead<List<Treatment>> between;
  ScriptedTreatmentsHistoryRepository(this.between);

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) => between([start, end]);
}
