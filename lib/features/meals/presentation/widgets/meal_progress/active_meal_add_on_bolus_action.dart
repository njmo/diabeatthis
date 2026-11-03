import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/meal/meal_add_on_bolus_context.dart';
import '../../../../../core/domain/model/meal_status_flow.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../meal_summary/presentation/utils/meal_summary_carbs_delta.dart';
import '../../../../meal_summary/presentation/utils/open_meal_summary_aaps_suggestion.dart';
import '../../../data/providers/meal_add_on_bolus_context_provider.dart';

class ActiveMealAddOnBolusAction extends ConsumerStatefulWidget {
  const ActiveMealAddOnBolusAction({super.key, required this.mealId});

  final int mealId;

  @override
  ConsumerState<ActiveMealAddOnBolusAction> createState() =>
      ActiveMealAddOnBolusActionState();
}

class ActiveMealAddOnBolusActionState
    extends ConsumerState<ActiveMealAddOnBolusAction> {
  bool opening = false;

  @override
  Widget build(BuildContext context) {
    final progress = ref
        .watch(mealAddOnBolusContextProvider(widget.mealId))
        .asData
        ?.value;
    if (progress == null || !progress.showCalculatorAction) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            progress.awaitingBolus
                ? context.lang.mealStatusWaitingForBolus
                : context.lang.mealAddOnExtendedCarbsInstruction,
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            onPressed: opening ? null : openCalculator,
            icon: const Icon(Icons.calculate_outlined),
            label: Text(context.lang.mealProgressOpenCalculator),
          ),
        ],
      ),
    );
  }

  Future<void> openCalculator() async {
    if (opening) return;
    setState(() => opening = true);
    try {
      final meal = await ref
          .read(databaseProvider)
          .mealDao
          .getMealById(widget.mealId);
      final progress = MealAddOnBolusContext.decode(meal?.addOnBolusContext);
      if (!mounted ||
          meal == null ||
          progress == null ||
          !(mealStatusesStartingEating.contains(meal.status) ||
              meal.status == 'eating-extra' ||
              meal.status == 'waiting-for-bolus' ||
              mealStatusReadyToSummarize(meal.status)) ||
          !progress.showCalculatorAction) {
        return;
      }
      await openMealAapsCarbsSuggestion(
        context: context,
        ref: ref,
        mealId: widget.mealId,
        mealName: meal.name,
        aapsCarbs: MealSummaryAapsCarbs(
          carbs: progress.requestedCarbs,
          extendedCarbs: progress.extendedCarbsConfirmed
              ? 0
              : progress.requestedExtendedCarbs,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.lang.aapsOpenFailed)));
      }
    } finally {
      if (mounted) setState(() => opening = false);
    }
  }
}
