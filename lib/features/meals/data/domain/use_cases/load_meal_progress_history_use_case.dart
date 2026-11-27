import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/data_sources/domain/treatments_history_repository.dart';
import '../../../../../core/data_sources/providers/source_repository_providers.dart';
import '../../../../../core/domain/model/bolus_wizard.dart';
import '../../../../../core/domain/model/extended_carb.dart';
import '../../models/meal_details_data.dart';
import '../../models/meal_progress_history.dart';

final loadMealProgressHistoryUseCaseProvider =
    Provider<LoadMealProgressHistoryUseCase>(
      (ref) => LoadMealProgressHistoryUseCase(
        repository: () => ref.read(treatmentsHistoryRepositoryProvider.future),
      ),
    );

/// Reads the treatment history of a meal that is still in progress. The full
/// glucose analysis stays reserved for eaten meals.
class LoadMealProgressHistoryUseCase {
  const LoadMealProgressHistoryUseCase({required this.repository});

  final Future<TreatmentsHistoryRepository> Function() repository;

  static const _lookBack = Duration(hours: 1);

  /// Scheduled eCarbs are stored with their future start time.
  static const _lookAhead = Duration(hours: 3);

  static bool appliesTo(MealDetailsData details) {
    final status = details.meal.status;
    return !details.meal.isEaten &&
        status != 'planned' &&
        status != 'skipped' &&
        status != 'interrupted';
  }

  Future<MealProgressHistory?> call(MealDetailsData details) async {
    if (!appliesTo(details)) return null;
    final started = details.statusHistory
        .where((entry) => entry.status != 'planned')
        .map((entry) => entry.createdAt)
        .fold<DateTime?>(
          null,
          (first, at) => first == null || at.isBefore(first) ? at : first,
        );
    final anchor = started ?? details.meal.plannedAt ?? details.meal.createdAt;
    final now = clock.now();
    final treatments = await (await repository()).fetchTreatmentsBetween(
      anchor.subtract(_lookBack),
      now.add(_lookAhead),
    );
    final calculators =
        treatments
            .whereType<BolusWizard>()
            .where(
              (wizard) =>
                  wizard.isValid &&
                  wizard.carbs.isFinite &&
                  wizard.carbs > 0 &&
                  !wizard.createdAt.isAfter(now),
            )
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final extendedCarbs =
        treatments
            .whereType<ExtendedCarb>()
            .where((carb) => carb.isValid && carb.carbs > 0)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return MealProgressHistory(
      calculators: calculators,
      extendedCarbs: extendedCarbs,
    );
  }
}
