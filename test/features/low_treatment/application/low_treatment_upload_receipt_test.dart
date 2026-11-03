import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_upload_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'verified V3 receipt links fractional intake without confusing its UUID with a V1 ObjectId',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final mealId = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Low treatment',
              plannedAt: 1000,
              purpose: const Value('lowTreatment'),
              status: const Value('confirmed'),
            ),
          );
      await db
          .into(db.lowTreatmentHandoff)
          .insert(
            LowTreatmentHandoffCompanion.insert(
              mealId: Value(mealId),
              savedAt: 1000,
              expectedCarbs: 12.5,
            ),
          );
      final repository = LowTreatmentUploadRepository(db);
      await repository.enqueue(
        mealId: mealId,
        identifier: '01234567-89ab-4cde-8fab-0123456789ab',
        sourceKey: 'hash',
        eatenAt: DateTime.fromMillisecondsSinceEpoch(1000),
        carbs: 12.5,
      );
      await repository.link(
        (await repository.find(mealId))!,
        '01234567-89ab-4cde-8fab-0123456789ab',
      );
      final receipt = (await db.select(db.lowTreatmentReview).get()).single;
      expect(receipt.mealId, mealId);
      expect(receipt.occurredAt, 1000);
      expect(receipt.externalId, isNull);
      expect(
        (await db.select(db.lowTreatmentHandoff).get()).single.matchedTreatAt,
        1000,
      );
      expect((await repository.find(mealId))!.state, 'sent');
      expect(await repository.hasMatchedTreatment(mealId), isTrue);
    },
  );
}
