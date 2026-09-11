import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  setUp(() => db = DatabaseImpl(NativeDatabase.memory()));
  tearDown(() => db.close());

  BolusWizardCompanion event({String? id, String? server}) =>
      BolusWizardCompanion.insert(
        source: 'cloud',
        createdAt: const Value(1000),
        nightscoutId: Value(id),
        remoteSource: Value(server),
        carbs: const Value(20),
        insulin: const Value(2),
      );

  for (final idFirst in [true, false]) {
    test('partial identities never form a pair, ID first: $idFirst', () async {
      final idOnly = event(id: 'legacy');
      final sourceOnly = event(server: 'https://example.com');
      await db.localMirrorDao.upsertBolusWizard(idFirst ? idOnly : sourceOnly);
      final original = await db.select(db.bolusWizard).getSingle();
      final meal = await db
          .into(db.meal)
          .insert(MealCompanion.insert(name: 'Lunch', plannedAt: 1000));
      final links = MealWizardLinkRepository(db);
      await links.link(
        mealId: meal,
        remoteWizardId: 'legacy',
        remoteSource: 'https://example.com',
      );
      await db.localMirrorDao.upsertBolusWizard(idFirst ? sourceOnly : idOnly);
      var saved = await db.select(db.bolusWizard).getSingle();
      expect(saved.localId, original.localId);
      expect(saved.nightscoutId, 'legacy');
      expect(saved.remoteSource, isNull);
      expect((await links.forMeal(meal)).single.localWizardId, isNull);

      // Only an explicit complete pair establishes the remote identity.
      await db.localMirrorDao.upsertBolusWizard(
        event(id: 'legacy', server: 'https://example.com'),
      );
      saved = await db.select(db.bolusWizard).getSingle();
      expect(saved.remoteSource, 'https://example.com');
      expect((await links.forMeal(meal)).single.localWizardId, saved.localId);
    });
  }

  test(
    'a confirmed pair survives all forms of later partial updates',
    () async {
      await db.localMirrorDao.upsertBolusWizard(
        event(id: 'known', server: 'https://example.com'),
      );
      for (final partial in [
        event(id: 'known'),
        event(server: 'https://example.com'),
        event(),
      ]) {
        await db.localMirrorDao.upsertBolusWizard(partial);
        final saved = await db.select(db.bolusWizard).getSingle();
        expect(saved.nightscoutId, 'known');
        expect(saved.remoteSource, 'https://example.com');
      }
    },
  );

  test('a conflicting complete pair cannot change the stored record', () async {
    await db.localMirrorDao.upsertBolusWizard(
      event(id: 'known', server: 'https://example.com'),
    );
    final saved = await db.select(db.bolusWizard).getSingle();
    for (final conflicting in [
      event(id: 'other', server: 'https://example.com'),
      event(id: 'known', server: 'https://other.example'),
    ]) {
      await expectLater(
        db.localMirrorDao.upsertBolusWizard(conflicting),
        throwsStateError,
      );
      expect(await db.select(db.bolusWizard).getSingle(), saved);
    }
  });
}
