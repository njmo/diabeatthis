import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/meal_details_controller.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;

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
