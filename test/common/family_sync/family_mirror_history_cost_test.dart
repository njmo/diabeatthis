import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/family_mirror_background_runtime.dart';
import 'package:diabeatthis/common/family_sync/family_mirror_integration.dart';
import 'package:diabeatthis/common/family_sync/publish_family_mirror_use_case.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/family_sync/family_mirror_outbox.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

void main() {
  test(
    'nutrition history mirrors recorded old values and cascade deletions',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO ingredient(name,carbs_per_100g,fat_per_100g,fiber_per_100g,protein_per_100g,nutrition_confidence) VALUES('Bread',40,2,3,8,1)",
      );
      await db.customStatement(
        'UPDATE ingredient SET carbs_per_100g=50 WHERE id=1',
      );
      final queue = FamilyMirrorOutbox(db);
      final history = (await queue.pending()).singleWhere(
        (row) => row.kind == 'ingredientHistory',
      );
      expect(history.payload!['carbs_per_100g'], 40);
      expect(history.payload!['ingredient_id'], 1);
      expect(
        (await queue.pending())
            .singleWhere((row) => row.kind == 'ingredients')
            .payload!['carbs_per_100g'],
        50,
      );
      await db.customStatement('DELETE FROM ingredient WHERE id=1');
      expect(
        (await queue.pending())
            .singleWhere((row) => row.kind == 'ingredientHistory')
            .deleted,
        true,
      );
    },
  );

  test(
    'empty or quarantined-only queue loads no identity and sends no request',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final transport = AuthenticatedCallableTransport(
        client: MockClient((_) async => throw StateError('Unexpected network')),
        projectId: 'test',
        currentUid: () => 'child',
        identity: () async => throw StateError('Unexpected token loading'),
      );
      final publish = PublishFamilyMirrorUseCase(
        outbox: FamilyMirrorOutbox(db),
        transport: transport,
        currentUid: () => 'child',
      );
      expect(await publish(), 0);
      await db.customStatement(
        "INSERT INTO portion(name,unit_hint) VALUES('Spoon','unit')",
      );
      await db.customStatement(
        'UPDATE family_sync_outbox SET failed_revision=revision',
      );
      expect(await publish(), 0);
      await db.customStatement('UPDATE family_sync_identity SET enabled=1');
      final runtime = FamilyMirrorBackgroundRuntime(db);
      addTearDown(runtime.dispose);
      await runtime.tick();
      expect(runtime.initialization, isNull);
    },
  );

  test(
    'family projection excludes local transport, therapy history and AI archives',
    () {
      final tables = familyMirrorIntegrations.map((row) => row.table);
      expect(
        tables,
        containsAll([
          'ingredient_status_history',
          'meal_status_history',
          'meal_snapshot',
          'activity_log',
        ]),
      );
      for (final excluded in [
        'glucose_reading',
        'device_status',
        'bolus_wizard',
        'temp_target_operation',
        'low_treatment_upload',
        'low_treatment_handoff',
        'accepted_meal_ai',
        'accepted_day_ai',
        'accepted_day_summary',
      ]) {
        expect(tables, isNot(contains(excluded)), reason: excluded);
      }
    },
  );
}
