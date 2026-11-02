import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/meal/meal_add_on_bolus_context.dart';
import '../../../../core/drift/providers/database_provider.dart';

final mealAddOnBolusContextProvider = StreamProvider.autoDispose
    .family<MealAddOnBolusContext?, int>((ref, mealId) {
      if (!ref.exists(databaseProvider)) return Stream.value(null);
      final db = ref.watch(databaseProvider);
      return (db.select(db.meal)..where((row) => row.id.equals(mealId)))
          .watchSingleOrNull()
          .map((meal) => MealAddOnBolusContext.decode(meal?.addOnBolusContext));
    });
