import 'package:diabeatthis/core/data_sources/local_mirror/history/local_device_status_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_glucose_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/analyze_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/models/meal_analysis_data.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../presentation/widgets/meal_details/meal_low_treatments_display_test.dart'
    show mealDetailsWithLowTreatment, mealRecord;

void main() {
  test(
    'analysis includes unlinked events by time and activities overlapping the window',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          glucoseHistoryRepositoryProvider.overrideWith(
            (ref) async => LocalGlucoseHistoryRepository(db.localMirrorDao),
          ),
          treatmentsHistoryRepositoryProvider.overrideWith(
            (ref) async => LocalTreatmentsHistoryRepository(db.localMirrorDao),
          ),
          deviceStatusHistoryRepositoryProvider.overrideWith(
            (ref) async =>
                LocalDeviceStatusHistoryRepository(db.localMirrorDao),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final details = mealDetailsWithLowTreatment().copyWith(lowTreatments: []);
      final time = details.analysisTime;
      Future<int> lowAt(int minutes) => db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Low $minutes',
              plannedAt: time
                  .add(Duration(minutes: minutes))
                  .millisecondsSinceEpoch,
              purpose: const Value('lowTreatment'),
              status: const Value('confirmed'),
            ),
          );
      final before = await lowAt(-30);
      final after = await lowAt(30);
      await lowAt(-61);
      await lowAt(91);
      final activity = await db
          .into(db.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'Activity',
              percentagePre: 80,
              percentagePost: 80,
            ),
          );
      await db
          .into(db.activityLog)
          .insert(
            ActivityLogCompanion.insert(
              activityId: activity,
              startedAt: time
                  .subtract(const Duration(hours: 2))
                  .millisecondsSinceEpoch,
              endedAt: Value(time.millisecondsSinceEpoch),
            ),
          );
      await db.localMirrorDao.upsertManualBolus(
        ManualBolusCompanion.insert(
          source: 'cloud',
          externalId: const Value('bolus'),
          createdAt: Value(time.millisecondsSinceEpoch),
          insulin: const Value(1),
        ),
      );
      final analysis = (await container
          .read(analyzeMealUseCaseProvider)
          .call(details))!;
      expect(analysis.lowTreatments.map((e) => e.mealId), [before, after]);
      expect(
        analysis.lowTreatments.every((e) => e.relatedMealId == null),
        isTrue,
      );
      expect(
        analysis.timelineEvents.where(
          (e) => e.type == MealTimelineEventType.lowTreatment,
        ),
        hasLength(2),
      );
      expect(analysis.linkedActivities, hasLength(1));
      expect(analysis.treatments, hasLength(1));
      // Existing linked entries retain their rich timeline presentation even
      // outside the new time-window query; window-only entries still appear.
      final original = mealDetailsWithLowTreatment().lowTreatments.single;
      final outside = MealLowTreatmentDetailsData(
        meal: mealRecord(
          id: 1001,
          name: 'Late low treatment',
          plannedAt: time.add(const Duration(hours: 4)),
          purpose: 'lowTreatment',
          status: 'confirmed',
        ),
        context: original.context.copyWith(mealId: 1001),
        ingredients: original.ingredients,
      );
      final sameRecord = MealLowTreatmentDetailsData(
        meal: mealRecord(
          id: after,
          name: 'Linked low treatment',
          plannedAt: time.add(const Duration(minutes: 30)),
          purpose: 'lowTreatment',
          status: 'confirmed',
        ),
        context: original.context.copyWith(mealId: after),
        ingredients: original.ingredients,
      );
      final withLinked = (await container
          .read(analyzeMealUseCaseProvider)
          .call(details.copyWith(lowTreatments: [sameRecord, outside])))!;
      final lowEvents = withLinked.timelineEvents
          .where((event) => event.type == MealTimelineEventType.lowTreatment)
          .toList();
      expect(lowEvents, hasLength(3));
      expect(
        lowEvents.where((event) => event.label == 'Late low treatment'),
        hasLength(1),
      );
      expect(
        lowEvents
            .singleWhere((event) => event.label == 'Linked low treatment')
            .value,
        contains('Glukoza 10 g'),
      );
      expect(withLinked.lowTreatments, hasLength(2));
    },
  );
}
