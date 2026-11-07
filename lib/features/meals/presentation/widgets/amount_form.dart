import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/ingredient_amount_calculator.dart';
import '../../../../common/planning/meal_amount_bindings.dart';
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
  const AmountForm({super.key, this.onEditReference, this.bindings});
  final MealAmountBindings? bindings;

  final VoidCallback? onEditReference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountNotifier = bindings == null
        ? ref.read(mealIngredientAmountDraftProvider.notifier)
        : null;
    final amount = bindings != null
        ? bindings!.amount
        : ref.watch(mealIngredientAmountDraftProvider);
    final confidenceNotifier = bindings == null
        ? ref.read(mealIngredientConfidenceDraftProvider.notifier)
        : null;
    final confidence = bindings != null
        ? bindings!.confidence
        : ref.watch(mealIngredientConfidenceDraftProvider);
    final formKey = bindings != null
        ? bindings!.formKey
        : ref.watch(mealIngredientFormKeyProvider);
    final draft = bindings != null
        ? bindings!.draft
        : ref.watch(mealIngredientsDraftProvider);
    final storedPortionAmount =
        bindings == null && draft.shouldLoadStoredPortionAmount
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
                    (bindings != null
                        ? null
                        : ref
                              .watch(
                                ingredientIconSuggestionProvider((
                                  draft.ingredient.name,
                                  draft.ingredient.brand,
                                )),
                              )
                              .asData
                              ?.value),
                name: draft.ingredient.name,
                description: draft.measureDescription(
                  gramsPerPortion: gramsPerPortion,
                  isLoading: isLoadingPortionAmount,
                ),
              ),
              if (bindings == null && !draft.ingredient.isReference) ...[
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
                          (bindings?.onAmount ?? amountNotifier!.setValue)(
                            value,
                          );
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
                onChanged:
                    bindings?.onConfidence ?? confidenceNotifier!.setConfidence,
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
