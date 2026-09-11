import 'package:diabeatthis/core/data_sources/providers/effective_history_source_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/meal_details_controller.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'history source failure preserves meal details instead of failing the page',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          effectiveHistorySourceProvider.overrideWith(
            (ref) => throw StateError('source unavailable'),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final meal = await db
          .into(db.meal)
          .insertReturning(
            MealCompanion.insert(
              name: 'Recorded meal',
              plannedAt: DateTime(2026, 9, 9, 12).millisecondsSinceEpoch,
              status: const Value('eaten'),
            ),
          );
      final provider = mealDetailsControllerProvider(meal.id);
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      final state = await container.read(provider.future);
      expect(state.details.meal.id, meal.id);
      expect(state.details.meal.name, 'Recorded meal');
      expect(state.analysis, isNull);
      expect(state.analysisError, contains('source unavailable'));
    },
  );
}
