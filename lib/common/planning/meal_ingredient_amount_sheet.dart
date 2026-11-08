import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../features/ingredients/data/drafts/ingredient_portion_draft.dart';
import '../../features/ingredients/data/models/ingredient_portion_data.dart';
import '../../features/meals/data/drafts/meal_draft.dart';
import '../../features/meals/presentation/widgets/amount_form.dart';
import '../../features/portions/data/drafts/portion_draft.dart';
import '../l10n/language.dart';
import '../nutrition/confidence_level.dart';
import '../widgets/keyboard_aware_bottom_sheet.dart';
import 'meal_amount_bindings.dart';
import 'meal_ingredient_portion_choices.dart';

class MealIngredientAmountSheet extends HookWidget {
  const MealIngredientAmountSheet({
    super.key,
    required this.draft,
    this.portions = const [],
  });
  final MealIngredientsDraft draft;
  final List<IngredientPortionData> portions;
  @override
  Widget build(BuildContext context) {
    final current = useState(draft);
    final amount = useState(draft.amount);
    final confidence = useState(
      ConfidenceLevelX.fromDouble01(draft.quantityConfidence),
    );
    final key = useMemoized(GlobalKey<FormState>.new);
    final choices = [...portions];
    draft.ingredientPortion.portion.maybeMap(
      existing: (saved) {
        final weight =
            draft.recordedGramsPerAmount ?? draft.ingredientPortion.amount;
        if (!choices.any((p) => p.portionId == saved.id) &&
            weight.isFinite &&
            weight > 0) {
          choices.add(
            IngredientPortionData(
              portionId: saved.id,
              name: saved.name,
              unitHint: saved.unitHint,
              gramsPerPortion: weight,
            ),
          );
        }
      },
      orElse: () {},
    );
    return KeyboardAwareBottomSheet(
      header: Text(
        context.lang.mealEditIngredientTooltip,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      body: AmountForm(
        bindings: MealAmountBindings(
          draft: current.value,
          portionChoices:
              choices.isEmpty || current.value.ingredient.isReference
              ? null
              : MealIngredientPortionChoices(
                  draft: current.value,
                  portions: choices,
                  onSelected: (portion) {
                    final currentPortion =
                        current.value.ingredientPortion.portion;
                    final selected = portion == null
                        ? const PortionSelection.empty()
                        : PortionSelection.existing(
                            id: portion.portionId,
                            name: portion.name,
                            unitHint: portion.unitHint,
                          );
                    final sameSavedPortion =
                        portion != null &&
                        currentPortion.maybeMap(
                          existing: (p) => p.id == portion.portionId,
                          orElse: () => false,
                        );
                    if (selected == currentPortion || sameSavedPortion) return;
                    final oldFactor =
                        current.value.recordedGramsPerAmount ??
                        current.value.ingredientPortion.amount;
                    if (!oldFactor.isFinite || oldFactor <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.lang.amountMissingPortionWeight,
                          ),
                        ),
                      );
                      return;
                    }
                    final newFactor = portion?.gramsPerPortion ?? 1.0;
                    amount.value = amount.value * oldFactor / newFactor;
                    current.value = current.value.copyWith(
                      ingredientPortion: IngredientPortionDraft(
                        portion: selected,
                        amount: newFactor,
                      ),
                      recordedGramsPerAmount: newFactor,
                    );
                  },
                ),
          amount: amount.value,
          confidence: confidence.value,
          formKey: key,
          onAmount: (v) => amount.value = v,
          onConfidence: (v) => confidence.value = v,
        ),
      ),
      actions: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.lang.settingsCancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton(
              onPressed: () {
                if (key.currentState?.validate() != true) return;
                final factor =
                    current.value.recordedGramsPerAmount ??
                    current.value.ingredientPortion.amount;
                if (!factor.isFinite || factor <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.lang.amountMissingPortionWeight),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  current.value.copyWith(
                    amount: amount.value,
                    quantityConfidence: confidence.value.toDouble01(),
                  ),
                );
              },
              child: Text(context.lang.commonSave),
            ),
          ),
        ],
      ),
    );
  }
}
