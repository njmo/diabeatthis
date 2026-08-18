import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/friendly_amount_selector.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/providers/add_ingredients_provider.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../utils/meal_ingredient_portion_formatters.dart';
import 'confidence_slider.dart';

class AmountForm extends ConsumerWidget {
  const AmountForm({super.key});

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
    final gramsPerPortion = _resolveGramsPerPortion(
      draft: draft,
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
          autovalidateMode: AutovalidateMode.always,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AmountFormInfo(
                draft: draft,
                gramsPerPortion: gramsPerPortion,
                isLoadingPortionAmount: isLoadingPortionAmount,
              ),
              const SizedBox(height: 16),
              FormField<double>(
                validator: (_) => amount > 0 ? null : '',
                builder: (field) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FriendlyAmountSelector(
                        value: amount,
                        min: 0,
                        step: draft.usesGramAmount ? 5 : 0.5,
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
                          context.lang.amountGreaterThanZero,
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
              Text(
                context.lang.amountConfidenceTitle,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              ConfidenceSlider(
                value: confidence,
                onChanged: confidenceNotifier.setConfidence,
              ),
            ],
          ),
        ),
      ),
    );
  }

  double? _resolveGramsPerPortion({
    required MealIngredientsDraft draft,
    required double? storedGramsPerPortion,
  }) {
    if (draft.usesGramAmount) {
      return 1;
    }
    if (draft.ingredient.isReference) {
      return 100;
    }
    if (draft.ingredientPortion.amount > 0) {
      return draft.ingredientPortion.amount;
    }
    return storedGramsPerPortion;
  }
}

class AmountFormInfo extends StatelessWidget {
  final MealIngredientsDraft draft;
  final double? gramsPerPortion;
  final bool isLoadingPortionAmount;

  const AmountFormInfo({
    required this.draft,
    required this.gramsPerPortion,
    required this.isLoadingPortionAmount,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(draft.ingredient.name, style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _description(context),
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _description(BuildContext context) {
    if (draft.usesGramAmount) {
      return context.lang.amountWeightInGramsHint;
    }
    if (isLoadingPortionAmount) {
      return context.lang.amountLoadingPortionWeight;
    }
    final amount = gramsPerPortion;
    if (amount == null || amount <= 0) {
      return context.lang.amountMissingPortionWeight;
    }
    return context.lang.amountPortionWeightDescription(
      unitLabelForAmount(1, draft.portionCountUnitLabel),
      amount.formattedAmount,
      draft.portionWeightUnitLabel,
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
      return const [
        FriendlyAmountOption(label: '50 g', value: 50),
        FriendlyAmountOption(label: '100 g', value: 100),
        FriendlyAmountOption(label: '150 g', value: 150),
      ];
    }

    return [
      FriendlyAmountOption(
        label: '1 ${unitLabelForAmount(1, unitLabel)}',
        value: 1,
      ),
      FriendlyAmountOption(
        label: '2 ${unitLabelForAmount(2, unitLabel)}',
        value: 2,
      ),
      FriendlyAmountOption(
        label: '5 ${unitLabelForAmount(5, unitLabel)}',
        value: 5,
      ),
    ];
  }
}
