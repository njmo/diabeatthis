import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meal_analysis/data/providers/meal_ai_provider.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_ai_context.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_meal_ai_context_use_case.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/controllers/meal_ai_input_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/regression/scripted_read.dart';
import 'meal_ai_test_fixtures.dart';

void main() {
  test(
    'explicit retry rebuilds failed context; retry on success does not read again',
    () async {
      final observation = await aiObservation();
      final loads = ScriptedRead<MealAiObservation>('recorded meal', [
        (
          arguments: [1, null],
          respond: () => throw StateError('Mocked history unavailable'),
        ),
        (arguments: [1, null], respond: () => observation),
      ]);
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('Unexpected database read'),
          ),
          buildMealAiContextUseCaseProvider.overrideWithValue(
            BuildMealAiContextUseCase(
              loadObservation: (id, cutoff) => loads([id, cutoff]),
              loadSimilar: (_) async => null,
              now: () => aiMealTime,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final provider = mealAiInputProvider(1);
      final subscription = container.listen(provider, (_, _) {});
      addTearDown(subscription.close);
      await expectLater(container.read(provider.future), throwsStateError);
      expect(container.read(provider).hasError, true);
      container.read(provider.notifier).retry();
      final document = await container.read(provider.future);
      expect(document.mealId, 1);
      expect(
        document.evidenceIds,
        containsAll(['meal', 'meal_before', 'meal_outcome']),
      );
      expect(document.text, contains('"net_carbs_g":30.0'));
      container.read(provider.notifier).retry();
      await container.pump();
      expect(loads.calls, hasLength(2));
      loads.verifyComplete();
    },
  );
}
