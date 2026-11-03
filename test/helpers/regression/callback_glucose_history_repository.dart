import 'package:diabeatthis/core/data_sources/domain/glucose_history_repository.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:flutter_test/flutter_test.dart';

class CallbackGlucoseHistoryRepository extends Fake
    implements GlucoseHistoryRepository {
  CallbackGlucoseHistoryRepository(this.recent);

  final Future<List<Glucose>> Function(int limit) recent;

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) => recent(limit);
}
