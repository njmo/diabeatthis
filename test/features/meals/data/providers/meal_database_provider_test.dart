import 'dart:async';

import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('status update provider finishes after auto-dispose pump', () async {
    final errors = <Object>[];

    await runZonedGuarded(() async {
      final completer = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          updateMealProvider.overrideWith((ref, args) async {
            await completer.future;
          }),
        ],
      );
      addTearDown(container.dispose);

      final update = container.read(
        updateMealProvider(const Meal(id: 1, name: 'Obiad'), 'eaten').future,
      );

      await container.pump();
      completer.complete();

      await update;
    }, (error, _) => errors.add(error));

    expect(errors, isEmpty);
  });
}
