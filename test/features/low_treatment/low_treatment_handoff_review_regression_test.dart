import 'package:diabeatthis/core/data_sources/domain/treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/temporary_target.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_handoff_repository.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/low_treatment_handoff_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 28, 12);
  late DatabaseImpl db;
  late LowTreatmentHandoffRepository repository;
  late ReviewHistory history;
  late LowTreatmentHandoffUseCase useCase;
  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    repository = LowTreatmentHandoffRepository(db);
    history = ReviewHistory();
    useCase = LowTreatmentHandoffUseCase(
      handoffs: repository,
      loadRecordedCarbs: (_) async => 10,
      loadHistory: () async => history,
    );
  });
  tearDown(() => db.close());
  var sequence = 0;
  Future<int> pending() async {
    final meal = await db.mealDao.createLowTreatmentEntry(
      name: 'Glucose ${sequence++}',
      eatenAt: start,
    );
    await useCase.registerPending(
      mealId: meal.id,
      savedAt: start,
      suggestionAt: start,
    );
    return meal.id;
  }

  Treat carb(int seconds) => Treat(
    externalId: 'carb-$seconds',
    createdAt: start.add(Duration(seconds: seconds)),
    carbs: 10,
  );
  Treatment wizard(int seconds) => TreatmentFactory().parseTreatments([
    {
      'eventType': 'Bolus Wizard',
      'created_at': start.add(Duration(seconds: seconds)).toIso8601String(),
      'glucose': 100,
      'bolusCalculatorResult': {'carbs': 10, 'totalInsulin': 1},
    },
  ]).single;

  test(
    'calculator carbs never confirm a low treatment, including local/remote copies',
    () async {
      await pending();
      history.items = [carb(60), wizard(65)];
      expect(
        await useCase.reconcile(
          now: start.add(const Duration(minutes: 2)),
          liveTreatments: [carb(60).copyWith(externalId: null)],
        ),
        isEmpty,
      );
      expect(await db.select(db.lowTreatmentReview).get(), isEmpty);
    },
  );
  test('offline batch keeps two matching entries ambiguous', () async {
    await pending();
    history.offline = true;
    expect(
      await useCase.reconcile(
        now: start.add(const Duration(minutes: 3)),
        liveTreatments: [carb(60), carb(120)],
      ),
      isEmpty,
    );
    expect(await db.select(db.lowTreatmentReview).get(), isEmpty);
  });
  test('offline batch still excludes calculator neighbours', () async {
    await pending();
    history.offline = true;
    expect(
      await useCase.reconcile(
        now: start.add(const Duration(minutes: 3)),
        liveTreatments: [carb(60), wizard(65)],
      ),
      isEmpty,
    );
  });
  test(
    'saved confirmation survives offline history with another unmatched meal',
    () async {
      final first = await pending();
      history.items = [carb(60)];
      expect(
        (await useCase.reconcile(
          now: start.add(const Duration(minutes: 2)),
        )).single.mealId,
        first,
      );
      await pending();
      history.offline = true;
      expect(
        (await useCase.reconcile(
          now: start.add(const Duration(minutes: 3)),
        )).single.mealId,
        first,
      );
    },
  );
  test(
    'waits for the calculator neighbour before matching a fresh carb',
    () async {
      await pending();
      history.offline = true;
      expect(
        await useCase.reconcile(
          now: start.add(const Duration(seconds: 65)),
          liveTreatments: [carb(60)],
        ),
        isEmpty,
      );
      expect(
        await useCase.reconcile(
          now: start.add(const Duration(seconds: 72)),
          liveTreatments: [carb(60), wizard(65)],
        ),
        isEmpty,
      );
    },
  );
  test(
    'one bounded history read includes the wizard beyond the match window',
    () async {
      await pending();
      await pending();
      history.items = [carb(300), wizard(305)];
      expect(
        await useCase.reconcile(now: start.add(const Duration(minutes: 6))),
        isEmpty,
      );
      expect(history.reads, 1);
      expect(
        history.end,
        start.add(const Duration(minutes: 5, seconds: 10, milliseconds: 1)),
      );
    },
  );
}

class ReviewHistory implements TreatmentsHistoryRepository {
  List<Treatment> items = [];
  bool offline = false;
  int reads = 0;
  DateTime? end;
  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) async {
    reads++;
    this.end = end;
    if (offline) throw StateError('offline');
    return items
        .where(
          (e) => !e.createdAt!.isBefore(start) && e.createdAt!.isBefore(end),
        )
        .toList();
  }

  @override
  Future<TemporaryTarget?> fetchLastTemporaryTarget() async => null;
}
