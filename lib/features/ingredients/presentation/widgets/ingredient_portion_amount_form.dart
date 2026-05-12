import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/friendly_amount_selector.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/ingredient_provider.dart';

class IngredientPortionAmountForm extends ConsumerWidget {
  const IngredientPortionAmountForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amountNotifier = ref.watch(
      ingredientPortionAmountDraftProvider.notifier,
    );
    final rawAmount = ref.watch(ingredientPortionAmountDraftProvider);
    final formKey = ref.watch(mealIngredientFormKeyProvider);
    final amount = rawAmount;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.always,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const IngredientPortionAmountHeader(),
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
                      step: 5,
                      options: IngredientPortionAmountOptions.options,
                      valueLabel: (value) => '${value.formatted} g',
                      onChanged: (value) {
                        amountNotifier.setValue(value);
                        field.didChange(value);
                      },
                    ),
                    if (field.hasError) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Wybierz wagę większą od zera.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class IngredientPortionAmountHeader extends StatelessWidget {
  const IngredientPortionAmountHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.secondaryContainer,
              foregroundColor: colorScheme.onSecondaryContainer,
              child: const Icon(Icons.scale_outlined),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Waga jednej porcji', style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Określ ile gramów ma porcja, którą dodajesz.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IngredientPortionAmountOptions {
  const IngredientPortionAmountOptions._();

  static const options = [
    FriendlyAmountOption(label: '25 g', value: 25, icon: Icons.scale_outlined),
    FriendlyAmountOption(label: '50 g', value: 50, icon: Icons.scale_outlined),
    FriendlyAmountOption(
      label: '100 g',
      value: 100,
      icon: Icons.check_circle_outline,
    ),
    FriendlyAmountOption(label: '150 g', value: 150, icon: Icons.add_outlined),
    FriendlyAmountOption(label: '200 g', value: 200, icon: Icons.add_chart),
  ];
}

extension IngredientPortionAmountDoubleX on double {
  String get formatted {
    if (this == roundToDouble()) {
      return toStringAsFixed(0);
    }
    return toStringAsFixed(1).replaceAll('.', ',');
  }
}
