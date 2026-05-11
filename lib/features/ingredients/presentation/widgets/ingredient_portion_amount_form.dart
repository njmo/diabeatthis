import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/ingredient_provider.dart';

class IngredientPortionAmountForm extends HookConsumerWidget {
  const IngredientPortionAmountForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealIngredientDraft = ref.watch(
      ingredientPortionAmountDraftProvider.notifier,
    );
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
                label: 'Wielkość porcji w gramach',
                value: '',
                onChanged: mealIngredientDraft.setAmount,
                builder: (context, controller) {
                  return TextFormField(
                    controller: controller,
                    maxLength: 30,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if ((value == null) ||
                          (value.isEmpty) ||
                          (int.tryParse(value) ?? 0) == 0) {
                        return '';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Ilość',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
