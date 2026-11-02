import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/ingredient_amount_calculator.dart';
import '../../../../common/widgets/friendly_amount_selector.dart';
import '../../../ingredients/data/icons/ingredient_icon_provider.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../data/providers/add_ingredients_provider.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../utils/meal_ingredient_portion_formatters.dart';
import 'confidence_slider.dart';
import 'ingredient_amount_portions.dart';
import 'meal_ingredient_review_header.dart';

class AmountForm extends ConsumerWidget {
  const AmountForm({super.key, this.onEditReference});

  final VoidCallback? onEditReference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountNotifier = ref.read(mealIngredientAmountDraftProvider.notifier);
    final amount = ref.watch(mealIngredientAmountDraftProvider);
    final confidenceNotifier = ref.read(
      mealIngredientConfidenceDraftProvider.notifier,
    );
    final confidence = ref.watch(mealIngredientConfidenceDraftProvider);
    final formKey = ref.watch(mealIngredientFormKeyProvider);
    final draft = ref.watch(mealIngredientsDraftProvider);
    final storedPortionAmount = draft.shouldLoadStoredPortionAmount
        ? ref.watch(
            gramsPerPortionProvider(
              draft.ingredient,
              draft.ingredientPortion.portion,
            ),
          )
        : null;
    final gramsPerPortion = resolveIngredientGramsPerPortion(
      kind: draft.amountKind,
      portionGrams: draft.ingredientPortion.amount,
      storedGramsPerPortion: storedPortionAmount?.maybeWhen(
        data: (value) => value,
        orElse: () => null,
      ),
    );
    final isLoadingPortionAmount = storedPortionAmount?.isLoading ?? false;
    final unitLabel = draft.portionCountUnitLabel;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.disabled,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MealIngredientReviewHeader(
                iconAssetPath:
                    draft.ingredient.iconAssetPath ??
                    ref
                        .watch(
                          ingredientIconSuggestionProvider((
                            draft.ingredient.name,
                            draft.ingredient.brand,
                          )),
                        )
                        .asData
                        ?.value,
                name: draft.ingredient.name,
                description: draft.measureDescription(
                  gramsPerPortion: gramsPerPortion,
                  isLoading: isLoadingPortionAmount,
                ),
              ),
              if (!draft.ingredient.isReference) ...[
                const SizedBox(height: 16),
                const IngredientAmountPortions(),
              ],
              if (draft.ingredient.isReference && onEditReference != null)
                TextButton.icon(
                  onPressed: onEditReference,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.lang.ingredientEditReferenceData),
                ),
              const SizedBox(height: 16),
              FormField<double>(
                validator: (_) =>
                    amount.isFinite &&
                        amount > 0 &&
                        !isLoadingPortionAmount &&
                        gramsPerPortion != null &&
                        gramsPerPortion > 0
                    ? null
                    : '',
                builder: (field) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FriendlyAmountSelector(
                        value: amount,
                        min: 0,
                        step: draft.usesGramAmount ? 5 : 1,
                        innerStep: draft.usesGramAmount ? 1 : 0.5,
                        additiveOptions: true,
                        options: AmountFormOptions.quickOptions(
                          unitLabel: unitLabel,
                          isGramAmount: draft.usesGramAmount,
                        ),
                        valueLabel: (value) =>
                            '${value.formattedAmount} ${unitLabelForAmount(value, unitLabel)}',
                        onChanged: (value) {
                          amountNotifier.setValue(value);
                          field.didChange(value);
                        },
                      ),
                      if (field.hasError) ...[
                        const SizedBox(height: 8),
                        Text(
                          gramsPerPortion == null || gramsPerPortion <= 0
                              ? context.lang.amountMissingPortionWeight
                              : context.lang.amountGreaterThanZero,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              ConfidenceSlider(
                value: confidence,
                title: context.lang.amountConfidenceTitle,
                onChanged: confidenceNotifier.setConfidence,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AmountFormOptions {
  const AmountFormOptions._();

  static List<FriendlyAmountOption> quickOptions({
    required String unitLabel,
    required bool isGramAmount,
  }) {
    if (isGramAmount) {
      return [
        for (final increment in [50.0, 100.0, 200.0])
          FriendlyAmountOption(
            label: lang.ingredientQuickAddAmount(
              increment.formattedAmount,
              'g',
            ),
            value: increment,
          ),
      ];
    }

    return [
      for (final increment in [0.5, 1.0, 2.0])
        FriendlyAmountOption(
          label: lang.ingredientQuickAddAmount(
            increment.formattedAmount,
            unitLabelForAmount(increment, unitLabel),
          ),
          value: increment,
        ),
    ];
  }
}
