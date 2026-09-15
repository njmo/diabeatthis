import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/forms.dart';
import '../../../ingredients/presentation/widgets/ingredient_form.dart';
import '../../../ingredients/presentation/widgets/ingredient_portion_amount_form.dart';
import '../../../ingredients/presentation/widgets/ingredient_search.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../../meals/presentation/widgets/summary.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../../portions/presentation/widgets/portion_form.dart';
import '../../../portions/presentation/widgets/portion_search.dart';
import '../../data/provider/add_meal_template_ingredients_provider.dart';
import '../../data/provider/meal_template_draft_provider.dart';
import 'amount_template_form.dart';

class AddMealTemplateIngredient extends ConsumerWidget {
  const AddMealTemplateIngredient({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(portionFilterProvider);
    final addingStage = ref.watch(addMealTemplateIngredientStageProvider);
    final addingStateNotifier = ref.read(
      addMealTemplateIngredientStageProvider.notifier,
    );
    if (addingStage == AddMealTemplateIngredientStage.dismiss) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      });
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switch (addingStage) {
            AddMealTemplateIngredientStage.dismiss => const SizedBox.shrink(),
            AddMealTemplateIngredientStage.ingredientSearch =>
              _textWithSearchTransition(
                context.lang.ingredientSearchLabel,
                Icon(Icons.add_box),
                addingStateNotifier,
              ),
            AddMealTemplateIngredientStage.ingredientForm =>
              _textWithSearchTransition(
                context.lang.templateIngredientForm,
                Icon(Icons.search),
                addingStateNotifier,
              ),
            AddMealTemplateIngredientStage.portionAddNewSearch =>
              _textWithSearchTransition(
                context.lang.templateIngredientPortionAdd,
                Icon(Icons.add),
                addingStateNotifier,
              ),
            AddMealTemplateIngredientStage.definedPortionsSearch =>
              _textWithSearchTransition(
                context.lang.templatePortionSearch,
                Icon(Icons.add_box),
                addingStateNotifier,
              ),
            AddMealTemplateIngredientStage.amountForm => Text(
              context.lang.uiAmountForm,
            ),
            AddMealTemplateIngredientStage.summary => Text(
              context.lang.addIngredientSummaryTitle,
            ),
            AddMealTemplateIngredientStage.portionSpecifyAmount => Text(
              context.lang.templatePortionIngredientAmount,
            ),
            AddMealTemplateIngredientStage.portionAddNewForm =>
              _textWithSearchTransition(
                context.lang.addIngredientNewPortionTitle,
                Icon(Icons.search),
                addingStateNotifier,
              ),
          },
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: switch (addingStage) {
              AddMealTemplateIngredientStage.dismiss => const SizedBox.shrink(),
              AddMealTemplateIngredientStage.ingredientSearch =>
                IngredientSearch(),
              AddMealTemplateIngredientStage.ingredientForm =>
                const SingleChildScrollView(child: IngredientForm()),
              AddMealTemplateIngredientStage.portionAddNewSearch =>
                PortionSearch(),
              AddMealTemplateIngredientStage.definedPortionsSearch =>
                PortionSearch(),
              AddMealTemplateIngredientStage.amountForm => AmountTemplateForm(),
              AddMealTemplateIngredientStage.summary => AddIngredientSummary(),
              AddMealTemplateIngredientStage.portionSpecifyAmount =>
                IngredientPortionAmountForm(
                  amount: ref.watch(
                    mealTemplateIngredientsDraftProvider.select(
                      (draft) => draft.ingredientPortion.amount,
                    ),
                  ),
                  onAmountChanged: ref
                      .read(mealTemplateIngredientsDraftProvider.notifier)
                      .setIngredientPortionAmount,
                ),
              AddMealTemplateIngredientStage.portionAddNewForm => PortionForm(),
            },
          ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (addingStage == AddMealTemplateIngredientStage.summary) {
                      Navigator.of(
                        context,
                      ).pop(ref.read(mealTemplateIngredientsDraftProvider));
                    } else {
                      final formKey = ref.read(mealIngredientFormKeyProvider);
                      if (validateForm(formKey)) {
                        addingStateNotifier.nextStage();
                      }
                    }
                  },
                  child: (addingStage == AddMealTemplateIngredientStage.summary)
                      ? Text(context.lang.mealSummaryExtraAdd)
                      : Text(context.lang.addIngredientNext),
                ),
              ),
              addingStage !=
                          AddMealTemplateIngredientStage
                              .definedPortionsSearch &&
                      addingStage !=
                          AddMealTemplateIngredientStage.portionAddNewSearch
                  ? SizedBox.shrink()
                  : Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          addingStateNotifier.setOverride();
                        },
                        child: Text(context.lang.uiAddByGrams),
                      ),
                    ),
              addingStage != AddMealTemplateIngredientStage.summary
                  ? SizedBox.shrink()
                  : Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final result = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                context.lang.addIngredientDiscardChangesTitle,
                              ),
                              content: Text(
                                context.lang.templateConfirmDiscard,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                  child: Text(context.lang.uiYes),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(false);
                                  },
                                  child: Text(context.lang.uiNo),
                                ),
                              ],
                            ),
                          );
                          if (result == true) {
                            if (context.mounted) {
                              Navigator.of(context).pop();
                            }
                          }
                        },
                        child: Text(context.lang.notificationActionReject),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _textWithSearchTransition(
    String text,
    Icon icon,
    AddMealTemplateIngredientStageNotifier notifier,
  ) {
    return Row(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: IconButton(
            onPressed: () => notifier.back(),
            icon: Icon(Icons.arrow_back),
          ),
        ),
        Expanded(child: Text(text)),
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            onPressed: () => notifier.toOppositeStage(),
            icon: icon,
          ),
        ),
      ],
    );
  }
}
