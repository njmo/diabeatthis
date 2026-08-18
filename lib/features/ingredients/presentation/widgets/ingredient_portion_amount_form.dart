import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/bottom_sheet_step_header.dart';
import '../../../../common/widgets/friendly_amount_selector.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/ingredient_provider.dart';

Future<double?> showIngredientPortionAmountSheet({
  required BuildContext context,
}) {
  return showModalBottomSheet<double>(
    context: context,
    useRootNavigator: false,
    isScrollControlled: true,
    builder: (_) => const _IngredientPortionAmountSheet(),
  );
}

class _IngredientPortionAmountSheet extends ConsumerStatefulWidget {
  const _IngredientPortionAmountSheet();

  @override
  ConsumerState<_IngredientPortionAmountSheet> createState() =>
      _IngredientPortionAmountSheetState();
}

class _IngredientPortionAmountSheetState
    extends ConsumerState<_IngredientPortionAmountSheet> {
  final formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return KeyboardAwareBottomSheet(
      header: BottomSheetStepHeader(
        title: lang.addIngredientPortionWeightTitle,
        onBack: () => Navigator.of(context).pop(),
      ),
      body: IngredientPortionAmountForm(
        formKey: formKey,
        amount: ref.watch(ingredientPortionAmountDraftProvider),
        onAmountChanged: ref
            .read(ingredientPortionAmountDraftProvider.notifier)
            .setValue,
      ),
      actions: FilledButton.icon(
        onPressed: _save,
        icon: const Icon(Icons.check),
        label: Text(lang.ingredientSavePortion),
      ),
    );
  }

  void _save() {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }
    Navigator.of(context).pop(ref.read(ingredientPortionAmountDraftProvider));
  }
}

class IngredientPortionAmountForm extends ConsumerWidget {
  const IngredientPortionAmountForm({
    super.key,
    required this.amount,
    required this.onAmountChanged,
    this.formKey,
  });

  final double amount;
  final ValueChanged<double> onAmountChanged;
  final GlobalKey<FormState>? formKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveFormKey =
        formKey ?? ref.watch(mealIngredientFormKeyProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: effectiveFormKey,
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
                        onAmountChanged(value);
                        field.didChange(value);
                      },
                    ),
                    if (field.hasError) ...[
                      const SizedBox(height: 8),
                      Text(
                        context.lang.amountGreaterThanZero,
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
    final lang = context.lang;
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
                  Text(
                    lang.ingredientOnePortionWeightTitle,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    lang.ingredientOnePortionWeightSubtitle,
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
