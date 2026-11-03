import 'package:diabeatthis/core/drift/dao/activity_dao.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:flutter_test/flutter_test.dart';

class ScriptedActivityDatabase extends Fake implements DatabaseImpl {
  @override
  final ActivityDao activityDao;
  ScriptedActivityDatabase(this.activityDao);
}
