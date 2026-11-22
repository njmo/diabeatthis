import 'dart:convert';
import 'dart:io';

import 'package:diabeatthis/common/family_sync/family_mirror_integration.dart';
import 'package:diabeatthis/common/meal/meal_treatment_surplus.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:diabeatthis/core/drift/family_sync/install_family_mirror_schema.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> addSyncTestIngredient(DatabaseImpl db) => db.customStatement(
  "INSERT INTO ingredient(name,carbs_per_100g,fat_per_100g,fiber_per_100g,protein_per_100g,nutrition_confidence) VALUES('Bread',40,2,3,8,1)",
);
void main() {
  test(
    'mirrors an idempotent surplus flag and keeps it after meal progress',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO meal (id, name, status) VALUES (1, 'Lunch', 'waiting-for-bolus')",
      );
      Future<({int revision, Map<String, dynamic> payload})> outbox() async {
        final row = await db
            .customSelect(
              "SELECT revision, payload FROM family_sync_outbox WHERE kind='meals' AND entity_id='1'",
            )
            .getSingle();
        return (
          revision: row.read<int>('revision'),
          payload:
              jsonDecode(row.read<String>('payload')) as Map<String, dynamic>,
        );
      }

      expect(
        (await outbox()).payload.containsKey('treatment_surplus'),
        isFalse,
      );
      await recordMealTreatmentSurplus(db, 1);
      final state = await outbox();
      expect(state.payload['treatment_surplus'], 1);
      await recordMealTreatmentSurplus(db, 1);
      expect((await outbox()).revision, state.revision);
      await db.mealDao.updateMealStatus(1, 'bolused-waiting');
      expect((await outbox()).payload['treatment_surplus'], 1);
    },
  );
  test(
    'only the extra bolus phase is mirrored, including context-only confirmation',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO meal (id, name, status) VALUES (1, 'Lunch', 'eating-extra')",
      );
      Future<({int revision, Map payload})> record() async {
        final row = await db
            .customSelect(
              "SELECT revision,payload FROM family_sync_outbox WHERE kind='meals' AND entity_id='1'",
            )
            .getSingle();
        return (
          revision: row.read<int>('revision'),
          payload: jsonDecode(row.read<String>('payload')) as Map,
        );
      }

      Future<void> save(bool waiting) => db.customStatement(
        'UPDATE meal SET add_on_bolus_context=? WHERE id=1',
        [
          jsonEncode({
            'version': 1,
            'originalStatus': 'eating-then-bolus',
            'awaitingBolus': waiting,
            'additionalServing': true,
            'bolusBeforeExtra': true,
            'acceptedWizardKeys': ['private'],
            'requestedCarbs': 20,
          }),
        ],
      );
      await save(true);
      final waiting = await record();
      expect(jsonDecode(waiting.payload['add_on_progress'] as String), {
        'originalStatus': 'eating-then-bolus',
        'awaitingBolus': 1,
        'additionalServing': 1,
        'bolusBeforeExtra': 1,
      });
      await save(false);
      final confirmed = await record();
      expect(confirmed.revision, greaterThan(waiting.revision));
      expect(
        jsonDecode(
          confirmed.payload['add_on_progress'] as String,
        )['awaitingBolus'],
        0,
      );
      expect(confirmed.payload.containsKey('add_on_bolus_context'), isFalse);
      expect(confirmed.payload['add_on_progress'], isNot(contains('private')));
    },
  );

  test(
    'existing active meals are exported once when upgrading the meal trigger',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO meal (id, name, status, add_on_bolus_context) VALUES (1, 'Lunch', 'eating-extra', ?)",
        [
          jsonEncode({
            'version': 1,
            'originalStatus': 'eating-then-bolus',
            'awaitingBolus': true,
            'acceptedWizardKeys': [],
          }),
        ],
      );
      await db.customStatement('DROP TRIGGER family_sync_meal_update');
      await db.customStatement(
        'CREATE TRIGGER family_sync_meal_update AFTER UPDATE ON meal BEGIN SELECT 1; END',
      );
      await db.customStatement(
        "UPDATE family_sync_outbox SET payload=json_remove(payload, '\$.add_on_progress'), acknowledged_revision=revision WHERE kind='meals'",
      );
      await installFamilyMirrorSchema(db);
      await installFamilyMirrorSchema(db);
      final row = await db
          .customSelect(
            "SELECT revision, acknowledged_revision, payload FROM family_sync_outbox WHERE kind='meals'",
          )
          .getSingle();
      expect(
        row.read<int>('revision'),
        row.read<int>('acknowledged_revision') + 1,
      );
      final payload = jsonDecode(row.read<String>('payload')) as Map;
      expect(
        jsonDecode(payload['add_on_progress'] as String)['awaitingBolus'],
        1,
      );
    },
  );

  test(
    'meal publication checks the selected meal and its dependencies',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = FamilyMirrorOutbox(db);
      final source = await queue.bindOwner('child');
      await addSyncTestIngredient(db);
      final mealId = await db
          .into(db.meal)
          .insert(MealCompanion.insert(name: 'Breakfast'));
      await db
          .into(db.mealIngredients)
          .insert(
            MealIngredientsCompanion.insert(
              mealId: mealId,
              ingredientId: 1,
              amount: const Value(1),
              quantityConfidence: 1,
            ),
          );
      expect(await queue.mealNeedsPublishing(mealId), isTrue);
      expect(await queue.mealNeedsPublishing(mealId + 1), isFalse);
      await queue.acknowledge('child', source, await queue.pending());
      expect(await queue.mealNeedsPublishing(mealId), isFalse);
      await db.customStatement("UPDATE ingredient SET name='Toast' WHERE id=1");
      expect(await queue.mealNeedsPublishing(mealId), isTrue);
    },
  );

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
