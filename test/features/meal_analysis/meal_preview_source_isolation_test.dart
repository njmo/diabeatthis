import 'package:diabeatthis/core/data_sources/domain/glucose_history_repository.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/similar_meal_glucose_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'preview succeeds without resolving treatments or device status providers',
    () async {
      final time = DateTime(2026, 5, 24, 12);
      final db = DatabaseImpl(NativeDatabase.memory());
      final repository = PreviewGlucoseRepository(time);
      var unrelatedReads = 0;
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          glucoseHistoryRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          treatmentsHistoryRepositoryProvider.overrideWith((ref) {
            unrelatedReads++;
            throw StateError('unavailable');
          }),
          deviceStatusHistoryRepositoryProvider.overrideWith((ref) {
            unrelatedReads++;
            throw StateError('unavailable');
          }),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final id = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Meal',
              plannedAt: time.millisecondsSinceEpoch,
              status: const Value('eaten'),
            ),
          );
      final provider = similarMealGlucoseProvider((
        mealId: id,
        asOf: time.add(const Duration(hours: 4)),
      ));
      final listener = container.listen(provider, (_, _) {});
      addTearDown(listener.close);
      final result = await container.read(provider.future);
      expect(result!.glucoseSummary.mean, 120);
      expect(repository.calls, 1);
      expect(unrelatedReads, 0);
    },
  );
}

class PreviewGlucoseRepository implements GlucoseHistoryRepository {
  final DateTime time;
  int calls = 0;
  PreviewGlucoseRepository(this.time);
  @override
  Future<List<Glucose>> fetchGlucoseBetween(
    DateTime start,
    DateTime end,
  ) async {
    calls++;
    return [
      for (var i = 0; i <= 90; i += 5)
        Glucose(
          externalId: null,
          source: GlucoseSource.cloud,
          date: time.add(Duration(minutes: i)),
          sgv: 120,
          direction: 'Flat',
        ),
    ];
  }

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) async =>
      throw UnimplementedError();
}
