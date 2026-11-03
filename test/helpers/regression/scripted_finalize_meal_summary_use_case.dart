import 'package:diabeatthis/features/meal_summary/domain/use_cases/finalize_meal_summary_use_case.dart';
import 'package:diabeatthis/features/meal_summary/presentation/models/meal_summary_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedFinalizeMealSummaryUseCase extends Fake
    implements FinalizeMealSummaryUseCase {
  final ScriptedRead<void> writes;
  ScriptedFinalizeMealSummaryUseCase(this.writes);

  @override
  Future<void> call(
    MealSummaryDraft draft, {
    MealSummarySaveMode mode = MealSummarySaveMode.finishMeal,
  }) => writes([draft, mode]);
}
