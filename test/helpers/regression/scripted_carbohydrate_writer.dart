import 'package:diabeatthis/core/data_sources/nightscout/treatments/nightscout_carbohydrate_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedCarbohydrateWriter extends Fake
    implements NightscoutCarbohydrateWriter {
  final ScriptedRead<String> responses;
  final bool beforeCreate;
  ScriptedCarbohydrateWriter(this.responses, {this.beforeCreate = true});
  @override
  Future<String> deliver({
    required String source,
    required String token,
    required String identifier,
    required DateTime eatenAt,
    required double carbs,
    required Future<void> Function() beforeCreate,
    required bool allowCreate,
  }) async {
    if (this.beforeCreate) await beforeCreate();
    return responses([
      source,
      token,
      identifier,
      eatenAt.millisecondsSinceEpoch,
      carbs,
      allowCreate,
    ]);
  }
}
