import 'package:diabeatthis/common/models/timeline_relation.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_relation_repository.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/update_low_treatment_relation_use_case.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  final at = DateTime(2026, 10, 28, 7, 50);
  setUp(() => db = DatabaseImpl(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> meal(
    String name,
    DateTime time, {
    String purpose = 'meal',
    String status = 'eaten',
  }) => db
      .into(db.meal)
      .insert(
        MealCompanion.insert(
          name: name,
          plannedAt: time.millisecondsSinceEpoch,
          purpose: Value(purpose),
          status: Value(status),
        ),
      );

  Future<int> activity(DateTime start, {DateTime? end}) async {
    final id = await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'PE',
            percentagePre: 0,
            percentagePost: 0,
          ),
        );
    return db
        .into(db.activityLog)
        .insert(
          ActivityLogCompanion.insert(
            activityId: id,
            startedAt: start.millisecondsSinceEpoch,
            endedAt: Value(end?.millisecondsSinceEpoch),
          ),
        );
  }

  test(
    'historical candidates include completed PE after consumption and eaten meals, nearest first',
    () async {
      final breakfast = await meal('Breakfast', DateTime(2026, 10, 28, 7));
      final pe = await activity(
        DateTime(2026, 10, 28, 8),
        end: DateTime(2026, 10, 28, 9),
      );
      await meal('Next day', DateTime(2026, 10, 29));
      await meal('Rescue', at, purpose: 'lowTreatment', status: 'confirmed');
      final candidates = await LowTreatmentRelationRepository(db).load(at, at);
      expect(candidates.map((e) => e.kind), [
        TimelineRelationKind.activity,
        TimelineRelationKind.meal,
      ]);
      expect(candidates.map((e) => e.id), [pe, breakfast]);
      expect(
        (await LowTreatmentRelationRepository(
          db,
        ).load(DateTime(2026, 10, 29), at)).single.name,
        'Next day',
      );
    },
  );

  test(
    'link, switch and detach preserve consumption and suggestion facts',
    () async {
      final low = await meal(
        'Rescue',
        at,
        purpose: 'lowTreatment',
        status: 'confirmed',
      );
      final breakfast = await meal(
        'Breakfast',
        at.subtract(const Duration(hours: 1)),
      );
      final pe = await activity(
        at.add(const Duration(minutes: 10)),
        end: at.add(const Duration(hours: 1)),
      );
      await db.lowTreatmentContextDao.upsertContextForMeal(
        LowTreatmentContextCompanion.insert(
          mealId: Value(low),
          source: 'dashboardAction',
          reason: const Value('fallingTrend'),
          suggestedCarbs: const Value(10),
          deviceStatusDate: Value(at.millisecondsSinceEpoch),
          isSynced: const Value(true),
        ),
      );
      final useCase = UpdateLowTreatmentRelationUseCase(db);
      await useCase(
        low,
        TimelineRelation(
          id: pe,
          kind: TimelineRelationKind.activity,
          name: 'PE',
          at: at,
        ),
      );
      var context = (await db.lowTreatmentContextDao.getContextForMeal(low))!;
      expect(context.relatedActivityLogId, pe);
      expect(context.relatedMealId, isNull);
      expect(context.reason.name, 'fallingTrend');
      expect(context.source.name, 'dashboardAction');
      expect(context.suggestedCarbs, 10);
      expect(context.deviceStatusDate, at);
      expect(context.isSynced, isFalse);
      await useCase(
        low,
        TimelineRelation(
          id: breakfast,
          kind: TimelineRelationKind.meal,
          name: 'Breakfast',
          at: at,
        ),
      );
      context = (await db.lowTreatmentContextDao.getContextForMeal(low))!;
      expect(context.relatedMealId, breakfast);
      expect(context.relatedActivityLogId, isNull);
      await useCase(low, null);
      context = (await db.lowTreatmentContextDao.getContextForMeal(low))!;
      expect(context.relatedMealId, isNull);
      expect(context.relatedActivityLogId, isNull);
      expect(context.suggestedCarbs, 10);
      final savedMeal = (await db.mealDao.getMealById(low))!;
      expect(savedMeal.plannedAt, at.millisecondsSinceEpoch);
      expect(savedMeal.status, 'confirmed');
    },
  );

  test(
    'creates missing context and rejects self links and missing targets',
    () async {
      final low = await meal(
        'Rescue',
        at,
        purpose: 'lowTreatment',
        status: 'confirmed',
      );
      final target = await meal('Breakfast', at);
      final useCase = UpdateLowTreatmentRelationUseCase(db);
      await useCase(
        low,
        TimelineRelation(
          id: target,
          kind: TimelineRelationKind.meal,
          name: 'Breakfast',
          at: at,
        ),
      );
      expect(
        (await db.lowTreatmentContextDao.getContextForMeal(low))!.relatedMealId,
        target,
      );
      for (final id in [low, 99999]) {
        await expectLater(
          useCase(
            low,
            TimelineRelation(
              id: id,
              kind: TimelineRelationKind.meal,
              name: 'Invalid',
              at: at,
            ),
          ),
          throwsStateError,
        );
      }
      await expectLater(
        useCase(
          low,
          TimelineRelation(
            id: 99999,
            kind: TimelineRelationKind.activity,
            name: 'Missing',
            at: at,
          ),
        ),
        throwsStateError,
      );
      expect(
        (await db.lowTreatmentContextDao.getContextForMeal(low))!.relatedMealId,
        target,
      );
    },
  );
}
