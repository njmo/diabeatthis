import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/domain/model/meal_macro_summary.dart';
import '../../../meal_analysis/data/providers/build_before_meal_context_use_case_provider.dart';
import '../../../meal_analysis/domain/models/before_meal_context.dart';
import '../models/meal_details_data.dart';

/// Separate lifecycle: a slow pre-meal fetch does not delay existing charts.
final mealBeforeContextProvider = FutureProvider.autoDispose
    .family<BeforeMealContext, ({MealDetailsData details, bool forceCloud})>((
      ref,
      request,
    ) {
      final details = request.details;
      final snapshot = details.plannedSnapshot ?? details.consumedSnapshot;
      final macros = snapshot == null
          ? null
          : MealMacroSummary(
              carbsGrams: snapshot.totalCarbsG,
              netCarbsGrams: snapshot.totalNetCarbsG,
              fatGrams: snapshot.totalFatG,
              proteinGrams: snapshot.totalProteinG,
              fiberGrams: snapshot.totalFiberG,
              totalGrams: snapshot.totalGrams,
            );
      return ref.watch(
        buildBeforeMealContextUseCaseProvider(request.forceCloud),
      )(asOf: details.analysisTime, mealId: details.meal.id, macros: macros);
    });
