import 'package:diabeatthis/core/drift/dao/activity_dao.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedActivityDao extends Fake implements ActivityDao {
  final ScriptedRead<ActivityData> updates;
  ScriptedActivityDao(this.updates);
  @override
  Future<ActivityData> updateActivity(ActivityCompanion value) => updates([
    value.id.value,
    value.name.value,
    value.percentagePre.value,
    value.percentagePost.value,
    value.durationMinutes.value,
  ]);
}
