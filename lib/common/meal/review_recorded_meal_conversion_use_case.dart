import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/drift/providers/database_provider.dart';
import 'recorded_meal_conversion_repository.dart';
import 'recorded_meal_conversion_request.dart';

final reviewRecordedMealConversionUseCaseProvider = Provider(
  (ref) => ReviewRecordedMealConversionUseCase(
    RecordedMealConversionRepository(ref.watch(databaseProvider)),
  ),
);

class ReviewRecordedMealConversionUseCase {
  const ReviewRecordedMealConversionUseCase(this.repository);
  final RecordedMealConversionRepository repository;

  Future<List<RecordedMealConversionRequest>> load(int mealId) =>
      repository.missingForMeal(mealId);
  Future<void> confirm(Map<RecordedMealConversionRequest, double> reviewed) =>
      repository.confirm(reviewed);
}
