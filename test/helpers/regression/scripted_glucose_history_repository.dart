import 'package:diabeatthis/core/data_sources/domain/glucose_history_repository.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedGlucoseHistoryRepository extends Fake
    implements GlucoseHistoryRepository {
  final ScriptedRead<List<Glucose>> between;
  ScriptedGlucoseHistoryRepository(this.between);

  @override
  Future<List<Glucose>> fetchGlucoseBetween(DateTime start, DateTime end) =>
      between([start, end]);
}
