import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/data_sources/nightscout/nightscout_storage_keys.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show MealData;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/common/temporary_targets/meal_target_links.dart';
import 'package:diabeatthis/features/dashboard/data/providers/temporary_target_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/controllers/dashboard_status_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/regression/scripted_meal_database.dart';
import '../../../../helpers/regression/scripted_meal_identity_dao.dart';
import '../../../../helpers/regression/scripted_read.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime.utc(2026, 9, 1, 12);
  final target = TemporaryTarget(
    nightscoutId: 'target-1',
    createdAt: now.subtract(const Duration(minutes: 5)),
    durationInMiliseconds: 2700000,
    duration: 45,
    targetBottom: 90,
    targetTop: 90,
  );
  for (final scenario in [
    'success',
    'source-changed',
    'target-changed',
    'expired',
    'missing-meal',
    'low-treatment',
  ]) {
    test(
      'dashboard attachment revalidates identity after the database read: $scenario',
      () => withClock(Clock.fixed(now), () async {
        SharedPreferences.setMockInitialValues({
          nightscoutUrlKey: 'https://first.test',
        });
        final prefs = await SharedPreferences.getInstance();
        final pending = Completer<MealData?>();
        final readStarted = Completer<void>();
        final reads = ScriptedRead<MealData?>('meal identity', [
          (
            arguments: [17],
            respond: () {
              readStarted.complete();
              return pending.future;
            },
          ),
        ]);
        final container = ProviderContainer(
          overrides: [
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            databaseProvider.overrideWithValue(
              ScriptedMealDatabase(ScriptedMealIdentityDao(reads)),
            ),
          ],
        );
        addTearDown(container.dispose);
        final provider = dashboardStatusControllerProvider;
        final subscription = container.listen(provider, (_, _) {});
        addTearDown(subscription.close);
        final selected = scenario == 'expired'
            ? target.copyWith(createdAt: now.subtract(const Duration(hours: 2)))
            : target;
        container.read(temporaryTargetUiProvider.notifier).update(selected);
        final controller = container.read(provider.notifier);
        final operation = controller.attachMeal(selected, 17);
        await readStarted.future;
        expect(container.read(provider).isLoading, true);
        await expectLater(
          controller.attachMeal(selected, 17),
          throwsStateError,
        );
        if (scenario == 'source-changed') {
          await prefs.setString(nightscoutUrlKey, 'https://second.test');
        }
        if (scenario == 'target-changed') {
          container.read(temporaryTargetUiProvider.notifier).clear();
        }
        final expectation = scenario == 'success'
            ? null
            : expectLater(operation, throwsStateError);
        pending.complete(
          scenario == 'missing-meal'
              ? null
              : MealData(
                  id: 17,
                  name: 'Meal',
                  plannedAt: now.millisecondsSinceEpoch,
                  purpose: scenario == 'low-treatment'
                      ? 'lowTreatment'
                      : 'meal',
                  status: 'planned',
                  createdAt: now.millisecondsSinceEpoch,
                  updatedAt: now.millisecondsSinceEpoch,
                  isSynced: false,
                ),
        );
        if (expectation != null) {
          await expectation;
          expect(container.read(provider).hasError, true);
          expect(prefs.getString(MealTargetLinks.storageKey), isNull);
        } else {
          await operation;
          expect(container.read(provider), const AsyncData<void>(null));
          expect(
            MealTargetLinks(prefs).mealId('https://first.test', selected),
            17,
          );
        }
        expect(
          prefs.getString(nightscoutUrlKey),
          scenario == 'source-changed'
              ? 'https://second.test'
              : 'https://first.test',
        );
        reads.verifyComplete();
      }),
    );
  }

  test(
    'missing Nightscout source fails before any meal database access',
    () async {
      SharedPreferences.setMockInitialValues({nightscoutUrlKey: '   '});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWith((ref) async => prefs),
          databaseProvider.overrideWith(
            (ref) => throw StateError('Unexpected database read'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(
        dashboardStatusControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await expectLater(
        container
            .read(dashboardStatusControllerProvider.notifier)
            .attachMeal(target, 17),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'No Nightscout source',
          ),
        ),
      );
      expect(prefs.getString(MealTargetLinks.storageKey), isNull);
    },
  );
}
