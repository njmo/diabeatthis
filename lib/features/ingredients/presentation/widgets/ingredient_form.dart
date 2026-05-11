import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../../meals/presentation/widgets/confidence_slider.dart';
import '../../data/providers/ingredient_provider.dart';
import 'reference_ingredient_checkbox.dart';

const int _ingredientNameMaxLength = 120;

class IngredientForm extends HookConsumerWidget {
  const IngredientForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.read(ingredientDraftProvider.notifier);
    final state = ref.watch(ingredientDraftProvider);
    final formKey = ref.watch(mealIngredientFormKeyProvider);

    return SingleChildScrollView(
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.always,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ReferenceIngredientCheckbox(),
            const SizedBox(height: 16),
            StringFormField(
              label: 'Nazwa',
              value: draft.getName(),
              onChanged: draft.setName,
              builder: (context, controller) {
                return TextFormField(
                  controller: controller,
                  maxLength: _ingredientNameMaxLength,
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty) {
                      return 'Podaj nazwę składnika';
                    }
                    if (name.length < 2) {
                      return 'Nazwa jest za krótka';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Nazwa',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            StringFormField(
              label: 'Producent',
              value: draft.getBrand(),
              onChanged: draft.setBrand,
              builder: (context, controller) {
                return TextFormField(
                  controller: controller,
                  maxLength: 30,
                  validator: (value) {
                    if ((value == null) ||
                        (value.isEmpty) ||
                        (value.length < 2)) {
                      return '';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Producent',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ConfidenceSlider(
              value: ConfidenceLevelX.fromDouble01(state.nutritionConfidence),
              onChanged: draft.setNutritionConfidence,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: StringFormField(
                    label: 'Ilość węglowodanów na 100g',
                    value: draft.getCarbsPer100g(),
                    onChanged: draft.setCarbsPer100g,
                    builder: (context, controller) {
                      return TextFormField(
                        controller: controller,
                        maxLength: 30,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if ((value == null) || (value.isEmpty)) {
                            return '';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Węglowodany',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: StringFormField(
                    label: 'Ilość tłuszczu na 100g',
                    value: draft.getFatPer100g(),
                    onChanged: draft.setFatPer100g,
                    builder: (context, controller) {
                      return TextFormField(
                        controller: controller,
                        maxLength: 30,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if ((value == null) || (value.isEmpty)) {
                            return '';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Tłuszcz',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: StringFormField(
                    label: 'Ilość białka na 100g',
                    value: draft.getProteinPer100g(),
                    onChanged: draft.setProteinPer100g,
                    builder: (context, controller) {
                      return TextFormField(
                        controller: controller,
                        maxLength: 30,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if ((value == null) || (value.isEmpty)) {
                            return '';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Białko',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: StringFormField(
                    label: 'Ilość błonnika na 100g',
                    value: draft.getFiberPer100g(),
                    onChanged: draft.setFiberPer100g,
                    builder: (context, controller) {
                      return TextFormField(
                        controller: controller,
                        maxLength: 30,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if ((value == null) || (value.isEmpty)) {
                            return '';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Błonnik',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
