import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_relation_type.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:diabeatthis/features/settings/data/database_backup_scope.dart';
import 'package:diabeatthis/features/settings/data/database_backup_service.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late MealWizardLinkRepository links;
  late int meal;
  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    links = MealWizardLinkRepository(db);
    meal = await db
        .into(db.meal)
        .insert(MealCompanion.insert(name: 'Lunch', plannedAt: 1000));
  });
  tearDown(() => db.close());
  Future<BolusWizardData> wizard(int time, {String? remote}) async {
    await db.localMirrorDao.upsertBolusWizard(
      BolusWizardCompanion.insert(
        source: remote == null ? 'aaps' : 'cloud',
        createdAt: Value(time),
        carbs: const Value(20),
        insulin: const Value(2),
        nightscoutId: Value(remote),
        remoteSource: Value(remote == null ? null : 'https://example.com'),
      ),
    );
    return (db.select(
      db.bolusWizard,
    )..where((row) => row.createdAt.equals(time))).getSingle();
  }

  test(
    'two 20g wizards link to one 40g meal without requiring a local mirror',
    () async {
      await links.link(
        mealId: meal,
        remoteWizardId: 'ns1',
        remoteSource: 'https://example.com/?token=secret',
      );
      await links.link(
        mealId: meal,
        remoteWizardId: 'ns2',
        remoteSource: 'https://example.com',
        relationType: MealWizardRelationType.continuation,
      );
      final rows = await links.forMeal(meal);
      expect(rows, hasLength(2));
      expect(rows.every((row) => row.localWizardId == null), isTrue);
      expect(rows.map((row) => row.remoteSource).toSet(), {
        'https://example.com',
      });
      expect(await db.select(db.bolusWizard).get(), isEmpty);
      expect((await db.select(db.meal).get()).single.name, 'Lunch');
    },
  );

  test(
    'sync enriches local-only and remote-only relations and replays do not duplicate links',
    () async {
      final first = await wizard(1000);
      await links.link(mealId: meal, localWizardId: first.localId);
      await links.link(
        mealId: meal,
        remoteWizardId: 'ns2',
        remoteSource: 'https://example.com',
      );
      await wizard(1000, remote: 'ns1');
      final second = await wizard(2000, remote: 'ns2');
      await wizard(1000);
      await links.link(mealId: meal, localWizardId: first.localId);
      await links.link(mealId: meal, localWizardId: second.localId);
      final rows = await links.forMeal(meal);
      expect(rows, hasLength(2));
      expect(
        rows.every(
          (row) => row.localWizardId != null && row.remoteWizardId != null,
        ),
        isTrue,
      );
    },
  );

  test(
    'compatible separate local and remote links consolidate atomically',
    () async {
      final local = await wizard(1000);
      await links.link(mealId: meal, localWizardId: local.localId);
      await links.link(
        mealId: meal,
        remoteWizardId: 'ns1',
        remoteSource: 'https://example.com',
      );
      expect(await links.forMeal(meal), hasLength(2));
      await wizard(1000, remote: 'ns1');
      final row = (await links.forMeal(meal)).single;
      expect(row.localWizardId, local.localId);
      expect(row.remoteWizardId, 'ns1');
    },
  );

  test('conflicting meal assignments roll back identity enrichment', () async {
    final other = await db
        .into(db.meal)
        .insert(MealCompanion.insert(name: 'Other', plannedAt: 2000));
    final local = await wizard(1000);
    await links.link(mealId: meal, localWizardId: local.localId);
    await links.link(
      mealId: other,
      remoteWizardId: 'ns1',
      remoteSource: 'https://example.com',
    );
    await expectLater(wizard(1000, remote: 'ns1'), throwsStateError);
    expect((await db.select(db.bolusWizard).get()).single.nightscoutId, isNull);
    expect(await links.forMeal(meal), hasLength(1));
    expect(await links.forMeal(other), hasLength(1));
    await expectLater(
      links.link(mealId: other, localWizardId: local.localId),
      throwsStateError,
    );
  });

  test(
    'remote-backed links survive mirror deletion and reattach on reimport',
    () async {
      final local = await wizard(1000, remote: 'ns1');
      await links.link(mealId: meal, localWizardId: local.localId);
      await db.localMirrorDao.deleteBolusWizard(local.toCompanion(true));
      final detached = (await links.forMeal(meal)).single;
      expect(detached.localWizardId, isNull);
      expect(detached.remoteWizardId, 'ns1');
      final imported = await wizard(1000, remote: 'ns1');
      expect(
        (await links.forMeal(meal)).single.localWizardId,
        imported.localId,
      );
      expect(imported.localId, isNot(local.localId));
    },
  );

  test(
    'invalid local-only event removes its link, but deleting a meal keeps wizard history',
    () async {
      final local = await wizard(1000);
      await links.link(mealId: meal, localWizardId: local.localId);
      await db.localMirrorDao.deleteBolusWizard(local.toCompanion(true));
      expect(await links.forMeal(meal), isEmpty);
      final remote = await wizard(2000, remote: 'ns2');
      await links.link(mealId: meal, localWizardId: remote.localId);
      await db.mealDao.deleteMealAndGeneratedData(meal);
      expect(await db.select(db.mealWizardLink).get(), isEmpty);
      expect(await db.select(db.bolusWizard).get(), hasLength(1));
    },
  );

  test('unverified identity pairs and missing identities are rejected', () async {
    final local = await wizard(1000);
    await expectLater(links.link(mealId: meal), throwsArgumentError);
    await expectLater(
      links.link(mealId: meal, remoteWizardId: 'ns1'),
      throwsArgumentError,
    );
    await expectLater(
      links.link(
        mealId: meal,
        localWizardId: local.localId,
        remoteWizardId: 'ns1',
        remoteSource: 'https://example.com',
      ),
      throwsStateError,
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO meal_wizard_link(meal_id,remote_wizard_id,relation_type) VALUES (?, 'ns1', 'initial')",
        [meal],
      ),
      throwsA(anything),
    );
    expect(await links.forMeal(meal), isEmpty);
  });
  test(
    'full backup roundtrip retains links and stable local identities',
    () async {
      final local = await wizard(1000, remote: 'ns1');
      await links.link(mealId: meal, localWizardId: local.localId);
      final backup = DatabaseBackupService(db);
      final exported = await backup.exportToJson(DatabaseBackupScope.full);
      await backup.importFromJson(exported);
      expect((await links.forMeal(meal)).single.localWizardId, local.localId);
      expect(
        (await db.select(db.bolusWizard).get()).single.localId,
        local.localId,
      );
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}
