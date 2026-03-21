import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../../meals/presentation/widgets/confidence_slider.dart';
import '../../data/provider/meal_template_draft_provider.dart';

class AmountTemplateForm extends HookConsumerWidget {
  const AmountTemplateForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealIngredientAmountDraft = ref.read(mealTemplateIngredientAmountDraftProvider.notifier);
    final mealIngredientAmountDraftState = ref.watch(mealTemplateIngredientAmountDraftProvider);
    final mealIngredientConfidenceDraft = ref.read(mealTemplateIngredientConfidenceDraftProvider.notifier);
    final mealIngredientConfidenceDraftState = ref.watch(mealTemplateIngredientConfidenceDraftProvider);
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
