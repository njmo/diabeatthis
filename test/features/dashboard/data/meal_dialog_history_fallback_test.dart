import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/core/data_sources/domain/device_status_history_repository.dart';
import 'package:diabeatthis/core/data_sources/domain/glucose_history_repository.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/meal_macro_summary.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    show DatabaseImpl, MealCompanion;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_state.dart';
import 'package:diabeatthis/features/dashboard/data/providers/blood_sugar_readings_list_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/device_status_ui_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_snapshot_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_snapshot_controller.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/ai_assisted_meal_advisor_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/extended_carbs_schedule_settings_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_eligibility.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_advice_unavailable_exception.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_ingredients_list_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../foreground/utils/fake_notifications_controller.dart';
import '../../../helpers/device_status_factory.dart';

void main() {
  test(
    'empty UI reads both histories and accepts without a UI status',
    () async {
      await withMealHistoryFixture((fixture) async {
        expect(fixture.container.read(deviceStatusUiProvider), isNull);
        expect(
          fixture.container.read(bloodSugarReadingsListProvider).requireValue,
          isEmpty,
        );

        await fixture.controller.chooseEat();
        expect(fixture.statuses.calls, 1);
        expect(fixture.glucose.calls, 1);
        expect(fixture.state.advice.decision, isNotNull);
        expect(fixture.state.carbsGrams, 45);
        expect(fixture.state.extendedCarbsGrams, 12);
        expect(fixture.state.unavailableReason, isNull);
        expect(fixture.container.read(deviceStatusUiProvider), isNull);
        expect(
          await fixture.db.select(fixture.db.mealAdvisorResult).get(),
          isEmpty,
        );

        expect(await fixture.controller.confirmAdvice(), isTrue);
        expect(fixture.statuses.calls, 2);
        expect(fixture.glucose.calls, 2);
        expect(
          await fixture.db.select(fixture.db.mealAdvisorResult).get(),
          hasLength(1),
        );
        expect(
          (await fixture.db.mealDao.getMealById(1))!.status,
          'waiting-for-bolus',
        );
        expect(fixture.container.read(deviceStatusUiProvider), isNull);
      });
    },
  );

  for (final invalidUi in ['stale', 'incomplete']) {
    test(
      '$invalidUi UI status is replaced by usable history for calculation',
      () async {
        await withMealHistoryFixture((fixture) async {
          final ui = invalidUi == 'stale'
              ? fixture.freshStatus.copyWith(
                  date: fixture.now.subtract(const Duration(minutes: 7)),
                )
              : fixture.freshStatus.copyWith(hasCob: false);
          fixture.container.read(deviceStatusUiProvider.notifier).update(ui);
          await fixture.controller.chooseEat();
          expect(fixture.statuses.calls, 1);
          expect(fixture.state.advice.decision, isNotNull);
          expect(fixture.state.unavailableReason, isNull);
          expect(fixture.state.preparationFailed, isFalse);
        });
      },
    );
  }

  for (final reason in [
    MealAdviceEligibility.missingDeviceStatus,
    MealAdviceEligibility.staleDeviceStatus,
    MealAdviceEligibility.incompleteDeviceStatus,
  ]) {
    test(
      'unusable device history reports $reason without saving a decision',
      () async {
        await withMealHistoryFixture((fixture) async {
          fixture.statuses.value = switch (reason) {
            MealAdviceEligibility.missingDeviceStatus => null,
            MealAdviceEligibility.staleDeviceStatus =>
              fixture.freshStatus.copyWith(
                date: fixture.now.subtract(const Duration(minutes: 6)),
              ),
            _ => fixture.freshStatus.copyWith(hasIob: false),
          };
          await fixture.controller.chooseEat();
          expect(fixture.state.advice.decision, isNull);
          expect(fixture.state.unavailableReason, reason);
          expect(fixture.state.preparationFailed, isFalse);
          expect(fixture.state.isPreparingAdvice, isFalse);
          expect(fixture.notifications.scheduledEvents, isEmpty);
          expect(
            await fixture.db.select(fixture.db.mealAdvisorResult).get(),
            isEmpty,
          );
        });
      },
    );
  }

  test('fresh pump history does not bypass stale CGM history', () async {
    await withMealHistoryFixture((fixture) async {
      fixture.glucose.readings = fixture.readings(ageMinutes: 10);
      await fixture.controller.chooseEat();
      expect(fixture.statuses.calls, 1);
      expect(fixture.glucose.calls, 1);
      expect(fixture.state.advice.decision, isNull);
      expect(
        fixture.state.unavailableReason,
        MealAdviceEligibility.staleReadings,
      );
      expect(fixture.notifications.scheduledEvents, isEmpty);
    });
  });

  test(
    'retry reads history again and clears the previous unavailable reason',
    () async {
      await withMealHistoryFixture((fixture) async {
        fixture.statuses.value = null;
        await fixture.controller.chooseEat();
        expect(
          fixture.state.unavailableReason,
          MealAdviceEligibility.missingDeviceStatus,
        );
        fixture.statuses.value = fixture.freshStatus;
        await fixture.controller.chooseEat();
        expect(fixture.statuses.calls, 2);
        expect(fixture.state.advice.decision, isNotNull);
        expect(fixture.state.unavailableReason, isNull);
      });
    },
  );

  for (final action in ['skip', 'back', 'manual', 'dispose']) {
    test(
      'late device history cannot overwrite $action during preparation',
      () async {
        await withMealHistoryFixture((fixture) async {
          final response = Completer<DeviceStatus?>();
          fixture.statuses.pending = response.future;
          final choosing = fixture.controller.chooseEat();
          await fixture.statuses.started.future;
          switch (action) {
            case 'skip':
              fixture.controller.chooseSkip();
            case 'back':
              fixture.controller.back();
            case 'manual':
              fixture.controller.cancelAdvicePreparation();
              await fixture.controller.chooseEat(
                manual: const ManualMealDecision(),
              );
            case 'dispose':
              fixture.disposeContainer();
          }
          response.complete(fixture.freshStatus);
          await choosing;
          expect(fixture.notifications.scheduledEvents, isEmpty);
          expect(
            await fixture.db.select(fixture.db.mealAdvisorResult).get(),
            isEmpty,
          );
          if (action == 'dispose') return;
          expect(fixture.state.isPreparingAdvice, isFalse);
          if (action == 'manual') {
            expect(fixture.state.advice.source, 'manual');
            expect(fixture.state.advice.decision, isNotNull);
          } else {
            expect(fixture.state.advice.decision, isNull);
            expect(fixture.state.skipMeal, action == 'skip');
            expect(
              fixture.state.step,
              action == 'back' ? MealDialogStep.choose : MealDialogStep.confirm,
            );
          }
        });
      },
    );
  }

  test(
    'new historical status cannot approve an expired original calculation',
    () async {
      await withMealHistoryFixture((fixture) async {
        await fixture.controller.chooseEat();
        fixture.now = fixture.now.add(const Duration(minutes: 6));
        fixture.statuses.value = fixture.freshStatus;
        fixture.glucose.readings = fixture.readings();
        await expectLater(
          fixture.controller.confirmAdvice(),
          throwsA(isA<MealAdviceUnavailableException>()),
        );
        expect(fixture.state.advice.decision, isNull);
        expect(
          fixture.state.unavailableReason,
          MealAdviceEligibility.staleDeviceStatus,
        );
        expect(
          await fixture.db.select(fixture.db.mealAdvisorResult).get(),
          isEmpty,
        );
        expect((await fixture.db.mealDao.getMealById(1))!.status, 'planned');
      });
    },
  );

  for (final action in ['skip', 'manual']) {
    test(
      'history revalidation cannot save over a newer $action choice',
      () async {
        await withMealHistoryFixture((fixture) async {
          await fixture.controller.chooseEat();
          final response = Completer<DeviceStatus?>();
          fixture.statuses.pending = response.future;
          fixture.statuses.started = Completer<void>();
          final confirming = fixture.controller.confirmAdvice();
          await fixture.statuses.started.future;
          if (action == 'skip') {
            fixture.controller.chooseSkip();
          } else {
            await fixture.controller.chooseEat(
              manual: const ManualMealDecision(),
            );
          }
          final newerAdvice = fixture.state.advice;
          response.complete(fixture.freshStatus);
          expect(await confirming, isFalse);
          expect(fixture.state.advice, same(newerAdvice));
          expect(fixture.state.skipMeal, action == 'skip');
          expect(
            await fixture.db.select(fixture.db.mealAdvisorResult).get(),
            isEmpty,
          );
          expect((await fixture.db.mealDao.getMealById(1))!.status, 'planned');
        });
      },
    );
  }
}

Future<void> withMealHistoryFixture(
  Future<void> Function(MealHistoryFixture fixture) body,
) async {
  final fixture = MealHistoryFixture();
  try {
    await withClock(Clock(() => fixture.now), () async {
      await fixture.initialize();
      await body(fixture);
    });
  } finally {
    fixture.disposeContainer();
    await fixture.db.close();
  }
}

class MealHistoryFixture {
  DateTime now = DateTime(2026, 11, 1, 12);
  final db = DatabaseImpl(NativeDatabase.memory());
  final statuses = MealDeviceHistoryRepository();
  final glucose = MealGlucoseHistoryRepository();
  final notifications = FakeNotificationsController();
  final provider = mealDialogControllerProvider(1, MealDialogStep.choose);
  late final ProviderContainer container;
  bool disposed = false;

  DeviceStatus get freshStatus =>
      testDeviceStatus(date: now, iob: 0, cob: 0, tick: '0', bg: 180);
  MealDialogController get controller => container.read(provider.notifier);
  MealDialogState get state => container.read(provider);

  List<Glucose> readings({int ageMinutes = 0}) => [
    for (final minutes in [10, 5, 0])
      Glucose(
        externalId: null,
        source: GlucoseSource.cloud,
        date: now.subtract(Duration(minutes: minutes + ageMinutes)),
        sgv: 180,
        direction: 'Flat',
      ),
  ];

  Future<void> initialize() async {
    statuses.value = freshStatus;
    glucose.readings = readings();
    await db
        .into(db.meal)
        .insert(
          MealCompanion.insert(
            name: 'History fallback meal',
            plannedAt: now.millisecondsSinceEpoch,
          ),
        );
    container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        databaseProvider.overrideWithValue(db),
        aiAssistedMealAdvisorEnabledProvider.overrideWithValue(false),
        notificationsControllerUiProvider.overrideWithValue(notifications),
        deviceStatusHistoryRepositoryProvider.overrideWith(
          (ref) async => statuses,
        ),
        glucoseHistoryRepositoryProvider.overrideWith((ref) async => glucose),
        mealBlockingActivationProvider(1).overrideWith((ref) async => null),
        extendedCarbsScheduleSettingsProvider.overrideWith(
          (ref) async => const ExtendedCarbsScheduleSettings.defaults(),
        ),
        mealMacronutrientsSummaryProvider(1).overrideWithValue(
          AsyncData(
            MealMacroSummary(
              carbsGrams: 45,
              fatGrams: 10,
              proteinGrams: 7.5,
              fiberGrams: 0,
              totalGrams: 180,
            ),
          ),
        ),
        mealSnapshotControllerProvider.overrideWith(
          (ref) => MealHistorySnapshotController(ref: ref),
        ),
      ],
    );
    container.listen(provider, (_, _) {});
  }

  void disposeContainer() {
    if (disposed) return;
    disposed = true;
    container.dispose();
  }
}

class MealDeviceHistoryRepository implements DeviceStatusHistoryRepository {
  DeviceStatus? value;
  Future<DeviceStatus?>? pending;
  Completer<void> started = Completer<void>();
  int calls = 0;

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) async {
    calls++;
    if (!started.isCompleted) started.complete();
    return pending == null ? value : await pending!;
  }

  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) => throw UnimplementedError();
}

class MealGlucoseHistoryRepository implements GlucoseHistoryRepository {
  List<Glucose> readings = [];
  int calls = 0;

  @override
  Future<List<Glucose>> fetchGlucoseBetween(
    DateTime start,
    DateTime end,
  ) async {
    calls++;
    return readings;
  }

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) =>
      throw UnimplementedError();
}

class MealHistorySnapshotController extends MealSnapshotController {
  MealHistorySnapshotController({required super.ref});

  @override
  Future<void> createPlannedSnapshot(int mealId) async {}
}
