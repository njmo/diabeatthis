import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/get_meal_activity_advice_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_activity_dose_suggestion.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/regression/controlled_preferences.dart';

void main() {
  final mealAt = DateTime(2026, 11, 3, 14);
  late DatabaseImpl db;
  late ProviderContainer container;
  late int activityId;
  setUp(() async {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPrefsProvider.overrideWith((_) async => ControlledPreferences()),
      ],
    );
    container.read(databaseProvider);
    activityId = await db
        .into(db.activity)
        .insert(
          ActivityCompanion.insert(
            name: 'Walk',
            percentagePre: 80,
            percentagePost: 70,
          ),
        );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<int> log({required int start, int? end}) => db
      .into(db.activityLog)
      .insert(
        ActivityLogCompanion.insert(
          activityId: activityId,
          startedAt: mealAt
              .add(Duration(minutes: start))
              .millisecondsSinceEpoch,
          endedAt: Value(
            end == null
                ? null
                : mealAt.add(Duration(minutes: end)).millisecondsSinceEpoch,
          ),
        ),
      );

  Future<int> occurrence({
    int start = 30,
    String status = 'pending',
    int? logId,
  }) => db
      .into(db.activityOccurrence)
      .insert(
        ActivityOccurrenceCompanion.insert(
          activityId: activityId,
          startedAt: mealAt
              .add(Duration(minutes: start))
              .millisecondsSinceEpoch,
          actionAt: mealAt.millisecondsSinceEpoch,
          confirmationMode: 'before',
          status: Value(status),
          activityLogId: Value(logId),
        ),
      );

  test(
    'future occurrence without a log is included at inclusive one-hour boundary',
    () async {
      await occurrence(start: 60);
      final result = await container.read(getMealActivityAdviceUseCaseProvider)(
        mealAt: mealAt,
      );
      expect(result!.dosePercent, 80);
      expect(result.phase, MealActivityPhase.upcoming);
    },
  );

  test(
    'completed long activity is included by end time at inclusive two-hour boundary',
    () async {
      await log(start: -300, end: -120);
      final result = await container.read(getMealActivityAdviceUseCaseProvider)(
        mealAt: mealAt,
      );
      expect(result!.dosePercent, 70);
      expect(result.phase, MealActivityPhase.completed);
    },
  );

  test(
    'ongoing activity is included even if start is outside query window',
    () async {
      await log(start: -300);
      final result = await container.read(getMealActivityAdviceUseCaseProvider)(
        mealAt: mealAt,
      );
      expect(result!.phase, MealActivityPhase.ongoing);
    },
  );

  for (final status in ['skipped', 'deleted', 'missed', 'cancelled']) {
    test('$status occurrence is not treated as a plan', () async {
      await occurrence(status: status);
      expect(
        await container.read(getMealActivityAdviceUseCaseProvider)(
          mealAt: mealAt,
        ),
        isNull,
      );
    });
  }

  test(
    'expired pending occurrence is not treated as performed activity',
    () async {
      await occurrence(start: -30);
      expect(
        await container.read(getMealActivityAdviceUseCaseProvider)(
          mealAt: mealAt,
        ),
        isNull,
      );
    },
  );

  test('confirmed occurrence uses its log exactly once', () async {
    final id = await log(start: -60, end: -30);
    await occurrence(start: -60, status: 'planned', logId: id);
    final result = await container.read(getMealActivityAdviceUseCaseProvider)(
      mealAt: mealAt,
    );
    expect(result!.dosePercent, 70);
    expect(result.phase, MealActivityPhase.completed);
  });

  test(
    'meal history anchors delayed handoff to eating start, not planned time',
    () async {
      final mealId = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Lunch',
              plannedAt: mealAt
                  .subtract(const Duration(hours: 4))
                  .millisecondsSinceEpoch,
              status: const Value('eaten'),
            ),
          );
      await db
          .into(db.mealStatusHistory)
          .insert(
            MealStatusHistoryCompanion.insert(
              mealId: mealId,
              status: 'bolused-eating',
              createdAt: Value(mealAt.millisecondsSinceEpoch),
            ),
          );
      await log(start: -60, end: -30);
      final result = await container.read(getMealActivityAdviceUseCaseProvider)(
        mealId: mealId,
      );
      expect(result!.dosePercent, 70);
    },
  );
}
