import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../features/meals/data/drafts/meal_draft.dart';
import '../../features/meals/presentation/widgets/amount_form.dart';
import '../l10n/language.dart';
import '../nutrition/confidence_level.dart';
import '../widgets/keyboard_aware_bottom_sheet.dart';
import 'meal_amount_bindings.dart';

class MealIngredientAmountSheet extends HookWidget {
  const MealIngredientAmountSheet({super.key, required this.draft});
  final MealIngredientsDraft draft;
  @override
  Widget build(BuildContext context) {
    final amount = useState(draft.amount);
    final confidence = useState(
      ConfidenceLevelX.fromDouble01(draft.quantityConfidence),
    );
    final key = useMemoized(GlobalKey<FormState>.new);
    return KeyboardAwareBottomSheet(
      header: Text(
        context.lang.mealEditIngredientTooltip,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      body: AmountForm(
        bindings: MealAmountBindings(
          draft: draft,
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
                Navigator.pop(
                  context,
                  draft.copyWith(
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
