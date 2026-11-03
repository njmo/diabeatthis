import 'package:diabeatthis/features/meal_summary/data/models/meal_summary_data.dart';
import 'package:diabeatthis/features/meal_summary/domain/use_cases/load_meal_summary_data_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedLoadMealSummaryUseCase extends Fake
    implements LoadMealSummaryDataUseCase {
  final ScriptedRead<MealSummaryData> reads;
  ScriptedLoadMealSummaryUseCase(this.reads);

  @override
  Future<MealSummaryData> call(int mealId) => reads([mealId]);
}
