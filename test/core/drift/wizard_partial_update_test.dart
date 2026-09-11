import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  setUp(() => db = DatabaseImpl(NativeDatabase.memory()));
  tearDown(() => db.close());

  BolusWizardCompanion event() => BolusWizardCompanion.insert(
    source: 'cloud',
    createdAt: const Value(1000),
    nightscoutId: const Value('wizard'),
    remoteSource: const Value('https://example.com'),
    carbs: const Value(20),
    insulin: const Value(2),
    percentageCorrection: const Value(80),
    wasCobUsed: const Value(true),
  );

  test(
    'partial external updates preserve calculator data while accepting zero and false',
    () async {
      await db.localMirrorDao.upsertBolusWizard(event());
      await db.localMirrorDao.upsertBolusWizard(
        event().copyWith(
          carbs: const Value(null),
          percentageCorrection: const Value(null),
          wasCobUsed: const Value(null),
        ),
      );
      var saved = await db.select(db.bolusWizard).getSingle();
      expect(saved.carbs, 20);
      expect(saved.percentageCorrection, 80);
      expect(saved.wasCobUsed, isTrue);
      await db.localMirrorDao.upsertBolusWizard(
        event().copyWith(
          carbs: const Value(0),
          percentageCorrection: const Value(0),
          wasCobUsed: const Value(false),
        ),
      );
      saved = await db.select(db.bolusWizard).getSingle();
      expect(saved.carbs, 0);
      expect(saved.percentageCorrection, 0);
      expect(saved.wasCobUsed, isFalse);
    },
  );

  test(
    'external invalidation rejects conflicting or unverified identities',
    () async {
      await db.localMirrorDao.upsertBolusWizard(event());
      for (final invalid in [
        event().copyWith(nightscoutId: const Value('other')),
        event().copyWith(remoteSource: const Value('https://other.com')),
        event().copyWith(
          nightscoutId: const Value(null),
          carbs: const Value(40),
        ),
        event().copyWith(
          nightscoutId: const Value(null),
          carbs: const Value(null),
          insulin: const Value(null),
        ),
      ]) {
        await expectLater(
          db.localMirrorDao.deleteBolusWizard(invalid),
          throwsStateError,
        );
        expect(await db.select(db.bolusWizard).get(), hasLength(1));
      }
      await db.localMirrorDao.deleteBolusWizard(event());
      expect(await db.select(db.bolusWizard).get(), isEmpty);
    },
  );

  test(
    'local invalidation can use matching calculator values without a remote ID',
    () async {
      await db.localMirrorDao.upsertBolusWizard(event());
      await db.localMirrorDao.deleteBolusWizard(
        event().copyWith(
          source: const Value('aaps'),
          nightscoutId: const Value(null),
          remoteSource: const Value(null),
        ),
      );
      expect(await db.select(db.bolusWizard).get(), isEmpty);
    },
  );
}
