import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart' hide AcceptedMealAi;
import 'package:diabeatthis/features/meal_analysis/data/repositories/meal_ai_repository.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_draft.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_result.dart';
import 'package:diabeatthis/features/settings/data/database_backup_scope.dart';
import 'package:diabeatthis/features/settings/data/database_backup_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_ai_test_fixtures.dart';

Future<AcceptedMealAi> archive({String model = 'test'}) async {
  final doc = await aiDocument();
  final raw = aiResponse();
  return AcceptedMealAi(
    acceptedAt: aiMealTime,
    draft: MealAiDraft(
      document: doc,
      result: MealAiResult.parse(
        raw,
        language: 'pl',
        evidenceIds: doc.evidenceIds,
      ),
      prompt: 'exact prompt',
      rawResponse: raw,
      modelId: model,
      generatedAt: aiMealTime,
      promptVersion: 1,
    ),
  );
}

void main() {
  test(
    'version31 upgrade, reopen and replacement retain exact accepted input and output',
    () async {
      final dir = await Directory.systemTemp.createTemp('meal-ai-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/db');
      var db = DatabaseImpl(NativeDatabase(file));
      await db.customStatement(
        "INSERT INTO meal(id,name,planned_at,status) VALUES(1,'Breakfast',0,'eaten')",
      );
      await db.customStatement('DROP TABLE accepted_meal_ai');
      await db.customStatement('PRAGMA user_version=31');
      await db.close();
      db = DatabaseImpl(NativeDatabase(file));
      final first = await archive();
      await MealAiRepository(db).save(first);
      await db.close();
      db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      final repo = MealAiRepository(db);
      final restored = (await repo.get(1))!;
      expect(restored.draft.document.text, first.draft.document.text);
      expect(restored.draft.prompt, 'exact prompt');
      expect(restored.draft.rawResponse, first.draft.rawResponse);
      expect(restored.acceptedAt, first.acceptedAt);
      await repo.save(await archive(model: 'replacement'));
      expect((await repo.get(1))!.draft.modelId, 'replacement');
      await db.customStatement('DELETE FROM meal WHERE id=1');
      expect(await repo.get(1), isNull);
    },
  );
  test(
    'full database backup includes and restores accepted meal analysis',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO meal(id,name,planned_at,status) VALUES(1,'Breakfast',0,'eaten')",
      );
      final original = await archive();
      await MealAiRepository(db).save(original);
      final backup = await DatabaseBackupService(
        db,
      ).exportToJson(DatabaseBackupScope.full);
      final target = DatabaseImpl(NativeDatabase.memory());
      addTearDown(target.close);
      await DatabaseBackupService(target).importFromJson(backup);
      final restored = (await MealAiRepository(target).get(1))!;
      expect(restored.draft.prompt, original.draft.prompt);
      expect(restored.draft.document.text, original.draft.document.text);
      expect(restored.draft.result.encode(), original.draft.result.encode());
    },
  );
  test('missing or uneaten meals cannot replace an accepted analysis', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = MealAiRepository(db);
    final saved = await archive();
    await expectLater(repo.save(saved), throwsStateError);
    await db.customStatement(
      "INSERT INTO meal(id,name,planned_at,status) VALUES(1,'Breakfast',0,'planned')",
    );
    await expectLater(repo.save(saved), throwsStateError);
    expect(await repo.get(1), isNull);
  });
}
