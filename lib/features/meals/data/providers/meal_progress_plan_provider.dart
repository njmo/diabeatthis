import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/meal/meal_progress_plan.dart';
import '../../../../core/domain/model/meal.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../dashboard/data/providers/meal_advisor_result_provider.dart';
import 'meal_add_on_bolus_context_provider.dart';

final mealProgressPlanProvider = StreamProvider.autoDispose
    .family<MealProgressPlan, Meal>((ref, meal) async* {
      final addOn = ref
          .watch(mealAddOnBolusContextProvider(meal.id))
          .asData
          ?.value;
      // The normal meal streams already own the database connection. A standalone
      // presentation of externally supplied meals can still show known stages
      // without opening a second persistence lifecycle just for decoration.
      if (!ref.exists(databaseProvider)) {
        yield mealProgressPlanForStatus(meal.status, addOn: addOn);
        return;
      }
      final advice = await ref.watch(getMealAdviceProvider(meal).future);
      final db = ref.watch(databaseProvider);
      final query = db.select(db.mealStatusHistory)
        ..where((row) => row.mealId.equals(meal.id));
      await for (final history in query.watch()) {
        yield mealProgressPlanForStatus(
          meal.status,
          decision: advice?.decision,
          history: history.map((entry) => entry.status),
          addOn: addOn,
        );
      }
    });
