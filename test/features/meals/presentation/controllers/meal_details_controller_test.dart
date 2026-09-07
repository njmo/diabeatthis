import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/providers/on_demand_history_repositories_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/meal_details_controller.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        dataSourceConfigProvider.overrideWithValue(
          AsyncData(
            const DataSourceConfig.defaults().copyWith(
              historySource: HistorySource.local,
            ),
          ),
        ),
        onDemandHistoryRepositoriesProvider.overrideWith(
          (ref) => throw StateError('Offline'),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'preserves local analysis and clears busy state after download failure',
    () async {
      final meal = await db
          .into(db.meal)
          .insertReturning(
            MealCompanion.insert(
              name: 'Obiad',
              plannedAt: DateTime(2026, 5, 24, 13).millisecondsSinceEpoch,
              status: const Value('eaten'),
            ),
          );
      final provider = mealDetailsControllerProvider(meal.id);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      final before = await container.read(provider.future);
      expect(before.analysis, isNotNull);
      final controller = container.read(provider.notifier);
      final download = controller.downloadHistory();
      expect(container.read(provider).value!.isDownloadingHistory, isTrue);
      await expectLater(download, throwsA(isA<StateError>()));
      final after = container.read(provider).value!;
      expect(after.isDownloadingHistory, isFalse);
      expect(after.analysis, same(before.analysis));
      expect(after.details, same(before.details));
    },
  );

  test('does not build meal page state for low treatment meals', () async {
    final lowTreatment = await db
        .into(db.meal)
        .insertReturning(
          MealCompanion.insert(
            name: 'Dosłodzenie',
            plannedAt: DateTime(2026, 5, 24, 13).millisecondsSinceEpoch,
            purpose: const Value('lowTreatment'),
            status: const Value('confirmed'),
          ),
        );

    final subscription = container.listen(
      mealDetailsControllerProvider(lowTreatment.id),
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await container.pump();
    await container.pump();

    final state = container.read(
      mealDetailsControllerProvider(lowTreatment.id),
    );
    expect(state.hasError, isTrue);
    expect(state.error, isA<LowTreatmentMealPageException>());
  });
}
