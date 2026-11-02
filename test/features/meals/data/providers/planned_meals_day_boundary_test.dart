import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/app/providers/app_lifecycle_state_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<DatabaseImpl> seedMeals(DateTime beforeMidnight) async {
    final db = DatabaseImpl(NativeDatabase.memory());
    final today = DateTime(
      beforeMidnight.year,
      beforeMidnight.month,
      beforeMidnight.day,
    );
    final oldDay = today.subtract(const Duration(days: 2));
    final nextDay = DateTime(today.year, today.month, today.day + 1);
    final seeds = [
      (name: 'Old active', at: oldDay, status: 'eating'),
      (name: 'Old eaten', at: oldDay, status: 'eaten'),
      (name: 'Old extra', at: oldDay, status: 'eaten-extra'),
      (name: 'Old bolused', at: oldDay, status: 'eaten-bolused'),
      (
        name: 'Previous day plan',
        at: today.add(const Duration(hours: 20)),
        status: 'planned',
      ),
      (
        name: 'New day plan',
        at: nextDay.add(const Duration(hours: 8)),
        status: 'planned',
      ),
    ];
    for (final seed in seeds) {
      await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: seed.name,
              plannedAt: seed.at.millisecondsSinceEpoch,
              status: Value(seed.status),
            ),
          );
    }
    return db;
  }

  Future<void> waitForTime(
    ProviderContainer container,
    DateTime expected,
    void Function() advance,
  ) async {
    final updated = Completer<void>();
    final subscription = container.listen(timeNowProvider, (_, next) {
      if (next.asData?.value == expected && !updated.isCompleted) {
        updated.complete();
      }
    });
    advance();
    await updated.future;
    subscription.close();
    await container.pump();
  }

  test(
    'only a new local day refreshes plans and keeps older active and summary meals',
    () async {
      final before = DateTime(2026, 12, 31, 23, 58);
      await withClock(Clock.fixed(before), () async {
        final db = await seedMeals(before);
        final ticks = StreamController<DateTime>();
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            timeNowProvider.overrideWith((ref) => ticks.stream),
          ],
        );
        final emissions = <List<String>>[];
        final subscription = container.listen(
          plannedMealsForTodayStreamProvider,
          (_, next) {
            final meals = next.asData?.value;
            if (meals != null) {
              emissions.add(meals.map((meal) => meal.name).toList());
            }
          },
        );
        try {
          await waitForTime(container, before, () => ticks.add(before));
          final initial = await container.read(
            plannedMealsForTodayStreamProvider.future,
          );
          expect(
            initial.map((meal) => meal.name),
            contains('Previous day plan'),
          );
          final emissionCount = emissions.length;

          final sameDay = before.add(const Duration(minutes: 1));
          await waitForTime(container, sameDay, () => ticks.add(sameDay));
          expect(emissions.length, emissionCount);

          final after = DateTime(2027, 1, 1, 0, 1);
          await waitForTime(container, after, () => ticks.add(after));
          final refreshed = await container.read(
            plannedMealsForTodayStreamProvider.future,
          );
          expect(
            refreshed.map((meal) => meal.name),
            unorderedEquals([
              'Old active',
              'Old eaten',
              'Old extra',
              'Old bolused',
              'New day plan',
            ]),
          );
        } finally {
          subscription.close();
          container.dispose();
          await ticks.close();
          await db.close();
        }
      });
    },
  );

  test(
    'resuming the app after midnight refreshes the plan without a new timer',
    () async {
      var currentTime = DateTime(2026, 11, 1, 23, 59);
      await withClock(Clock(() => currentTime), () async {
        final db = await seedMeals(currentTime);
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        final subscription = container.listen(
          plannedMealsForTodayStreamProvider,
          (_, _) {},
        );
        try {
          final initial = await container.read(
            plannedMealsForTodayStreamProvider.future,
          );
          expect(
            initial.map((meal) => meal.name),
            contains('Previous day plan'),
          );
          container
              .read(appLifecycleProvider.notifier)
              .setState(AppLifecycleState.paused);
          await container.pump();

          currentTime = DateTime(2026, 11, 2, 8);
          await waitForTime(container, currentTime, () {
            container
                .read(appLifecycleProvider.notifier)
                .setState(AppLifecycleState.resumed);
          });
          final refreshed = await container.read(
            plannedMealsForTodayStreamProvider.future,
          );
          expect(
            refreshed.map((meal) => meal.name),
            isNot(contains('Previous day plan')),
          );
          expect(
            refreshed.map((meal) => meal.name),
            containsAll([
              'Old active',
              'Old eaten',
              'Old extra',
              'Old bolused',
              'New day plan',
            ]),
          );
        } finally {
          subscription.close();
          container.dispose();
          await db.close();
        }
      });
    },
  );
}
