import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('version 30 database gains the low treatment handoff table', () async {
    final dir = await Directory.systemTemp.createTemp('handoff-migration-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/history.sqlite');
    var db = DatabaseImpl(NativeDatabase(file));
    await db.customStatement('DROP TABLE low_treatment_handoff');
    await db.customStatement('PRAGMA user_version = 30');
    await db.close();

    db = DatabaseImpl(NativeDatabase(file));
    addTearDown(db.close);
    final table = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'low_treatment_handoff'",
        )
        .getSingleOrNull();
    expect(table, isNotNull);
  });
}
