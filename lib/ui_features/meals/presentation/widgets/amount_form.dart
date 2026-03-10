import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../data/providers/add_ingredients_provider.dart';
import '../../data/providers/meal_draft_provider.dart';
import 'confidence_slider.dart';

class AmountForm extends HookConsumerWidget {
  const AmountForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealIngredientAmountDraft = ref.read(mealIngredientAmountDraftProvider.notifier);
    final mealIngredientAmountDraftState = ref.watch(mealIngredientAmountDraftProvider);
    final mealIngredientConfidenceDraft = ref.read(mealIngredientConfidenceDraftProvider.notifier);
    final mealIngredientConfidenceDraftState = ref.watch(mealIngredientConfidenceDraftProvider);
    final formKey = ref.watch(mealIngredientFormKeyProvider);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.always,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StringFormField(
                label: 'Ilość porcji',
                value: mealIngredientAmountDraftState.toStringAsFixed(0),
                onChanged: mealIngredientAmountDraft.setAmount,
                builder: (context, controller) {
                  return TextFormField(
                    controller: controller,
                    maxLength: 30,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if ((value == null) || (value.isEmpty) || (int.tryParse(value) ?? 0) == 0) {
                        return '';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Ilość porcji',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              ConfidenceSlider(
                value: mealIngredientConfidenceDraftState,
                onChanged: mealIngredientConfidenceDraft.setConfidence,
              )
            ],
          ),
        ),
      ),
    );
  }
}
