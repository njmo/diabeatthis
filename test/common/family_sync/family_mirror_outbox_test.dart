import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/common/family_sync/family_mirror_integration.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> addSyncTestIngredient(DatabaseImpl db) => db.customStatement(
  "INSERT INTO ingredient(name,carbs_per_100g,fat_per_100g,fiber_per_100g,protein_per_100g,nutrition_confidence) VALUES('Bread',40,2,3,8,1)",
);
void main() {
  test('Dart and backend use the same projection contracts', () {
    final remote =
        jsonDecode(
              File(
                'backend/family/common/mirror_contract.json',
              ).readAsStringSync(),
            )
            as Map;
    for (final integration in familyMirrorIntegrations) {
      expect(remote[integration.kind], {
        'table': integration.table,
        'keys': integration.keys,
        'columns': integration.columns,
      });
    }
    expect(remote.length, familyMirrorIntegrations.length);
  });
  test(
    'local edits, cascaded deletes and acknowledgement races remain durable without network',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await addSyncTestIngredient(db);
      final queue = FamilyMirrorOutbox(db);
      final source = await queue.bindOwner('child');
      final first = (await queue.pending()).firstWhere(
        (row) => row.kind == 'ingredients',
      );
      await db.customStatement(
        "UPDATE ingredient SET name='Wholemeal bread' WHERE id=1",
      );
      await queue.acknowledge('child', source, [first]);
      final changed = (await queue.pending()).firstWhere(
        (row) => row.kind == 'ingredients',
      );
      expect(changed.revision, greaterThan(first.revision));
      expect(changed.payload!['name'], 'Wholemeal bread');
      await queue.acknowledge('child', source, [changed]);
      expect(
        (await queue.pending()).where((row) => row.kind == 'ingredients'),
        isEmpty,
      );
      await db.customStatement('DELETE FROM ingredient WHERE id=1');
      final deleted = (await queue.pending()).firstWhere(
        (row) => row.kind == 'ingredients',
      );
      expect(deleted.deleted, true);
      expect(deleted.payload, isNull);
      expect(
        (await queue.pending())
            .firstWhere((row) => row.kind == 'ingredientOrigins')
            .deleted,
        true,
      );
      await expectLater(queue.bindOwner('another-child'), throwsStateError);
    },
  );
  test(
    'capture rolls back with the original transaction and does not edit legacy synced flags',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await expectLater(
        db.transaction(() async {
          await addSyncTestIngredient(db);
          throw StateError('Rollback');
        }),
        throwsStateError,
      );
      expect(await FamilyMirrorOutbox(db).pending(), isEmpty);
      await addSyncTestIngredient(db);
      final queue = FamilyMirrorOutbox(db);
      final source = await queue.bindOwner('child');
      await queue.acknowledge('child', source, await queue.pending());
      expect(await queue.pending(), isEmpty);
      expect(
        (await db.customSelect('SELECT is_synced FROM ingredient').getSingle())
            .read<int>('is_synced'),
        0,
      );
    },
  );
}
