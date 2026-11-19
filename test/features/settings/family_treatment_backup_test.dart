import 'dart:convert';

import 'package:diabeatthis/core/domain/model/low_treatment_context.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/family_treatment_journal.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/recorded_low_treatment_repository.dart';
import 'package:diabeatthis/features/settings/data/database_backup_scope.dart';
import 'package:diabeatthis/features/settings/data/database_backup_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> seed(DatabaseImpl db, String source, int delivery) async {
  await db.customStatement(
    "INSERT INTO meal(id,name,planned_at,status,purpose) VALUES(1,'',1000,'confirmed','lowTreatment')",
  );
  await db
      .into(db.lowTreatmentContext)
      .insert(
        LowTreatmentContextCompanion.insert(
          mealId: const Value(1),
          source: source,
          recordedCarbs: Value(delivery),
        ),
      );
  await db
      .into(db.mealSnapshot)
      .insert(
        MealSnapshotCompanion.insert(
          mealId: 1,
          snapshotType: 'consumed',
          totalGrams: 10,
          totalCarbsG: 6.49,
          totalFiberG: 0,
          totalNetCarbsG: 6.49,
          totalFatG: 0,
          totalProteinG: 0,
          totalCaloriesKcal: 25.96,
          createdAt: const Value(1000),
          updatedAt: const Value(1000),
        ),
      );
}

void main() {
  test(
    'clinical backup preserves family nutrition without exporting the private receipt',
    () async {
      final source = DatabaseImpl(NativeDatabase.memory());
      final target = DatabaseImpl(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(target.close);
      await seed(source, 'familyChat', 6);
      await FamilyTreatmentJournal(source).prepare(
        uid: 'child',
        familyId: 'family',
        messageId: 'request',
        installationId: 'phone',
        proof: 'PRIVATE_PROOF',
      );
      final payload = await DatabaseBackupService(
        source,
      ).exportToJson(DatabaseBackupScope.full);
      expect(jsonEncode(payload), isNot(contains('PRIVATE_PROOF')));
      expect(
        (payload['tables'] as Map).keys,
        isNot(contains('family_treatment_journal')),
      );
      await DatabaseBackupService(target).importFromJson(payload);
      final record = (await RecordedLowTreatmentRepository(
        target,
      ).fetchByMealId(1))!;
      expect(record.source, LowTreatmentContextSource.familyChat);
      expect(record.historicalNutritionCarbsGrams, 6.49);
      expect(record.netCarbsGrams, 6);
      expect(
        await FamilyTreatmentJournal(target).find('child', 'family', 'request'),
        isNull,
      );
    },
  );

  test(
    'restore ID collision cannot assign old receipt provenance or repeat its effect',
    () async {
      final source = DatabaseImpl(NativeDatabase.memory());
      final target = DatabaseImpl(NativeDatabase.memory());
      addTearDown(source.close);
      addTearDown(target.close);
      await seed(source, 'manual', 12);
      await seed(target, 'familyChat', 6);
      final journal = FamilyTreatmentJournal(target);
      final operation = await journal.prepare(
        uid: 'child',
        familyId: 'family',
        messageId: 'request',
        installationId: 'phone',
        proof: 'RETAINED_PROOF',
      );
      await journal.apply(
        operation,
        authorized: () async => true,
        save: () async => 1,
        elapsedMilliseconds: () => 0,
        deadlineMilliseconds: 10000,
        appliedAt: 1000,
      );
      final payload = await DatabaseBackupService(
        source,
      ).exportToJson(DatabaseBackupScope.full);
      await DatabaseBackupService(target).importFromJson(payload);
      final record = (await RecordedLowTreatmentRepository(
        target,
      ).fetchByMealId(1))!;
      expect(record.source, LowTreatmentContextSource.manual);
      expect(record.historicalNutritionCarbsGrams, 12);
      final retained = (await journal.find('child', 'family', 'request'))!;
      expect(retained.proof, 'RETAINED_PROOF');
      expect(await journal.find('another-child', 'family', 'request'), isNull);
      var saves = 0;
      expect(
        await journal.apply(
          retained,
          authorized: () async => true,
          save: () async {
            saves++;
            return 2;
          },
          elapsedMilliseconds: () => 0,
          deadlineMilliseconds: 10000,
          appliedAt: 2000,
        ),
        1,
      );
      expect(saves, 0);
      expect((await target.select(target.meal).get()).length, 1);
    },
  );
}
