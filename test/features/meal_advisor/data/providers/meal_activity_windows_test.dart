import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/get_meal_activity_advice_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/meal_activity_windows_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/regression/controlled_preferences.dart';

void main() {
  late ControlledPreferences prefs;
  late ProviderContainer container;
  setUp(() {
    prefs = ControlledPreferences();
    container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWith((_) async => prefs)],
    );
  });
  tearDown(() => container.dispose());

  test(
    'optional activity advice does not initialize unrelated storage without an active database',
    () async {
      final isolated = ProviderContainer();
      addTearDown(isolated.dispose);
      expect(
        await isolated.read(getMealActivityAdviceUseCaseProvider)(mealId: 7),
        isNull,
      );
      expect(isolated.exists(databaseProvider), isFalse);
      expect(isolated.exists(sharedPrefsProvider), isFalse);
    },
  );

  test('defaults are two hours back and one hour ahead', () async {
    final result = await container.read(mealActivityWindowsProvider.future);
    expect(result.pastMinutes, 120);
    expect(result.futureMinutes, 60);
  });

  test(
    'saving one window preserves the other and refreshes the provider',
    () async {
      await container.read(mealActivityWindowsProvider.future);
      final controller = container.read(mealActivityWindowsControllerProvider);
      await controller.savePastMinutes(180);
      var result = await container.read(mealActivityWindowsProvider.future);
      expect(result.pastMinutes, 180);
      expect(result.futureMinutes, 60);
      await controller.saveFutureMinutes(30);
      result = await container.read(mealActivityWindowsProvider.future);
      expect(result.pastMinutes, 180);
      expect(result.futureMinutes, 30);
      expect(prefs.writes, [
        (key: mealActivityPastMinutesKey, value: 180),
        (key: mealActivityFutureMinutesKey, value: 30),
      ]);
    },
  );

  test(
    'concurrent independent saves do not overwrite the other window',
    () async {
      final controller = container.read(mealActivityWindowsControllerProvider);
      await Future.wait([
        controller.savePastMinutes(240),
        controller.saveFutureMinutes(90),
      ]);
      final result = await container.read(mealActivityWindowsProvider.future);
      expect(result.pastMinutes, 240);
      expect(result.futureMinutes, 90);
    },
  );

  test('zero disables a window and survives provider recreation', () async {
    await container
        .read(mealActivityWindowsControllerProvider)
        .saveFutureMinutes(0);
    container.invalidate(mealActivityWindowsProvider);
    expect(
      (await container.read(mealActivityWindowsProvider.future)).futureMinutes,
      0,
    );
  });

  test(
    'failed persistence throws and leaves the displayed source unchanged',
    () async {
      await container.read(mealActivityWindowsProvider.future);
      prefs.acceptWrites = false;
      await expectLater(
        container
            .read(mealActivityWindowsControllerProvider)
            .savePastMinutes(30),
        throwsStateError,
      );
      expect(
        (await container.read(mealActivityWindowsProvider.future)).pastMinutes,
        120,
      );
    },
  );

  test('invalid values are rejected before any write', () async {
    for (final value in [-1, 1441]) {
      await expectLater(
        container
            .read(mealActivityWindowsControllerProvider)
            .savePastMinutes(value),
        throwsArgumentError,
      );
    }
    expect(prefs.writes, isEmpty);
  });

  test('corrupt stored windows fall back to safe defaults', () async {
    prefs.values[mealActivityPastMinutesKey] = -10;
    final result = await container.read(mealActivityWindowsProvider.future);
    expect(result.pastMinutes, 120);
    expect(result.futureMinutes, 60);
  });
}
