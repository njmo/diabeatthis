import 'package:diabeatthis/core/data_sources/nightscout/dto/bolus_wizard_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/bolus_wizard_mapper.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_local_history_repository.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_meal_review_use_case.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_relation_type.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late MealWizardLinkRepository links;
  final day = DateTime(2026, 9, 11);
  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    links = MealWizardLinkRepository(db);
  });
  tearDown(() => db.close());

  domain.BolusWizard wizard(
    String id,
    DateTime time, {
    String server = 'https://example.com',
  }) => BolusWizardDto.fromJson({
    '_id': id,
    'created_at': time.toUtc().toIso8601String(),
    'glucose': 120,
    'bolusCalculatorResult': {'carbs': 20, 'totalInsulin': 2},
  }).toDomain(remoteSource: server);

  Future<int> meal(String name, DateTime time) => db
      .into(db.meal)
      .insert(
        MealCompanion.insert(
          name: name,
          plannedAt: time.millisecondsSinceEpoch,
          status: const Value('summarized'),
        ),
      );

  BuildDayMealReviewUseCase useCase(List<Treatment> treatments) {
    final local = DayLocalHistoryRepository(db);
    return BuildDayMealReviewUseCase(
      loadTreatments: (_, _) async => treatments,
      loadAssignments: links.forWizards,
      loadMeals: (start, end, ids) =>
          local.loadRecordedMeals(start, end, includeIds: ids),
      now: () => day.add(const Duration(days: 1)),
    );
  }

  test(
    'two 20g entries group under their confirmed meal without a local mirror',
    () async {
      final id = await meal('Breakfast', day.add(const Duration(hours: 8)));
      await links.link(
        mealId: id,
        remoteWizardId: 'first',
        remoteSource: 'https://example.com',
      );
      await links.link(
        mealId: id,
        remoteWizardId: 'second',
        remoteSource: 'https://example.com',
        relationType: MealWizardRelationType.continuation,
      );
      final review = await useCase([
        wizard('second', day.add(const Duration(hours: 9))),
        wizard('first', day.add(const Duration(hours: 8))),
      ])(day);
      expect(review, hasLength(1));
      expect(review.single.meal!.name, 'Breakfast');
      expect(review.single.wizards.map((w) => w.nightscoutObjectId), [
        'first',
        'second',
      ]);
      expect(
        review.single.assignments.last.type,
        MealWizardRelationType.continuation,
      );
      expect(await db.select(db.bolusWizard).get(), isEmpty);
    },
  );

  test(
    'similar times do not create a link and remote IDs are scoped to server',
    () async {
      final id = await meal('Breakfast', day.add(const Duration(hours: 8)));
      await links.link(
        mealId: id,
        remoteWizardId: 'same',
        remoteSource: 'https://other.example',
      );
      final review = await useCase([
        wizard('same', day.add(const Duration(hours: 8))),
      ])(day);
      expect(review, hasLength(2));
      expect(review.where((e) => e.meal == null).single.wizards, hasLength(1));
      expect(review.where((e) => e.meal != null).single.wizards, isEmpty);
    },
  );

  test(
    'a continuation can belong to the previous day and invalid or out-of-day entries are omitted',
    () async {
      final id = await meal(
        'Late dinner',
        day.subtract(const Duration(minutes: 30)),
      );
      await links.link(
        mealId: id,
        remoteWizardId: 'continuation',
        remoteSource: 'https://example.com',
        relationType: MealWizardRelationType.continuation,
      );
      final review = await useCase([
        wizard('continuation', day.add(const Duration(minutes: 30))),
        wizard(
          'invalid',
          day.add(const Duration(hours: 1)),
        ).copyWith(isValid: false),
        wizard('tomorrow', day.add(const Duration(days: 1))),
      ])(day);
      expect(review, hasLength(1));
      expect(review.single.meal!.id, id);
      expect(review.single.wizards, hasLength(1));
    },
  );

  test(
    'history failures do not turn into an empty successful review',
    () async {
      final useCase = BuildDayMealReviewUseCase(
        loadTreatments: (_, _) async => throw StateError('offline'),
        loadAssignments: links.forWizards,
        loadMeals: (_, _, _) async => [],
        now: () => day,
      );
      await expectLater(useCase(day), throwsStateError);
    },
  );
}
