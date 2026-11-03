import 'package:diabeatthis/core/data_sources/domain/treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    show DatabaseImpl, LowTreatmentContextCompanion;
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_handoff_repository.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/low_treatment_handoff_use_case.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 11, 3, 14, 38, 55);
  for (final duration in [0, 60]) {
    test(
      'AAPS carbs duration=$duration only confirms immediate intake',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        final meal = await db.mealDao.createLowTreatmentEntry(
          name: 'Glucose',
          eatenAt: start,
        );
        await db
            .into(db.lowTreatmentContext)
            .insert(
              LowTreatmentContextCompanion.insert(
                mealId: Value(meal.id),
                source: 'manual',
                recordedCarbs: const Value(8),
              ),
            );
        final payload = TreatmentFactory().parseTreatments([
          {
            'eventType': 'Carb Correction',
            'created_at': start
                .add(const Duration(seconds: 7))
                .toIso8601String(),
            'carbs': 8,
            'duration': duration,
            '_id': 'receipt-77',
          },
        ]);
        final useCase = LowTreatmentHandoffUseCase(
          handoffs: LowTreatmentHandoffRepository(db),
          loadRecordedCarbs: (_) async => 8,
          loadHistory: () async => EmptyCarbHistory(),
        );
        await useCase.registerPending(
          mealId: meal.id,
          savedAt: start,
          suggestionAt: null,
        );
        final matches = await useCase.reconcile(
          now: start.add(const Duration(minutes: 1)),
          liveTreatments: payload,
        );
        expect(matches, duration == 0 ? hasLength(1) : isEmpty);
        expect(
          (await db.lowTreatmentContextDao.getContextForMeal(
            meal.id,
          ))!.recordedCarbs,
          8,
        );
      },
    );
  }
}

class EmptyCarbHistory extends Fake implements TreatmentsHistoryRepository {
  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) async => [];
}
