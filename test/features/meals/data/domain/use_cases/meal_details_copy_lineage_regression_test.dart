import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/load_meal_details_use_case.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;
  final at = DateTime.utc(2026, 9, 1, 12).millisecondsSinceEpoch;
  Future<int> meal(String name, int time, {int? source, int? template}) => db
      .into(db.meal)
      .insert(
        MealCompanion.insert(
          name: name,
          plannedAt: time,
          status: const Value('summarized'),
          basedOnMealId: Value(source),
          mealTemplateId: Value(template),
          createdAt: Value(time),
          updatedAt: Value(time),
        ),
      );
  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'direct and template copies appear once in chronological order and cannot include their source',
    () async {
      final source = await meal('Original', at);
      final template = await db
          .into(db.mealTemplate)
          .insert(
            MealTemplateCompanion.insert(
              name: 'From original',
              createdFromMealId: Value(source),
            ),
          );
      final unrelatedTemplate = await db
          .into(db.mealTemplate)
          .insert(MealTemplateCompanion.insert(name: 'Unrelated'));
      final direct = await meal('Direct copy', at + 1000, source: source);
      final shared = await meal(
        'Both links',
        at + 2000,
        source: source,
        template: template,
      );
      final fromTemplate = await meal(
        'Template copy',
        at + 3000,
        template: template,
      );
      await meal('Unrelated', at + 4000, template: unrelatedTemplate);
      await (db.update(db.meal)..where((row) => row.id.equals(source))).write(
        MealCompanion(
          mealTemplateId: Value(template),
          basedOnMealId: Value(source),
        ),
      );
      final details = await container.read(loadMealDetailsUseCaseProvider)(
        source,
      );
      expect(details.copyUsages.map((copy) => copy.id), [
        fromTemplate,
        shared,
        direct,
      ]);
      expect(details.copyUsages.map((copy) => copy.name), [
        'Template copy',
        'Both links',
        'Direct copy',
      ]);
      expect(
        details.copyUsages.map((copy) => copy.plannedAt.millisecondsSinceEpoch),
        [at + 3000, at + 2000, at + 1000],
      );
      expect(
        details.copyUsages.every((copy) => copy.status == 'summarized'),
        true,
      );
      expect(details.plannedSnapshot, isNull);
      expect(details.consumedSnapshot, isNull);
      expect(details.plannedPreviewNutrition, isNull);
    },
  );

  test(
    'copy source is identified by ID rather than a matching meal name',
    () async {
      final source = await meal('Same name', at);
      await meal('Same name', at + 1000);
      final copy = await meal('Copy', at + 2000, source: source);
      final details = await container.read(loadMealDetailsUseCaseProvider)(
        copy,
      );
      expect(details.copySource!.id, source);
      expect(details.copySource!.name, 'Same name');
      expect(details.copyUsages, isEmpty);
    },
  );

  test(
    'deleted copy source does not manufacture provenance or historical nutrition',
    () async {
      final source = await meal('Deleted source', at);
      final copy = await meal('Copy', at + 1000, source: source);
      await (db.delete(db.meal)..where((row) => row.id.equals(source))).go();
      final details = await container.read(loadMealDetailsUseCaseProvider)(
        copy,
      );
      expect(details.copySource, isNull);
      expect(details.copyUsages, isEmpty);
      expect(details.plannedPreviewNutrition, isNull);
    },
  );

  test(
    'missing meal fails explicitly instead of returning empty historical facts',
    () async {
      await expectLater(
        container.read(loadMealDetailsUseCaseProvider)(999),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Meal 999 was not found',
          ),
        ),
      );
    },
  );
}
