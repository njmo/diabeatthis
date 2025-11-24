import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/ingredient_provider.dart';

class IngredientForm extends HookConsumerWidget {
  const IngredientForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(ingredientDraftProvider.notifier);
    final formKey = ref.watch(mealIngredientFormKeyProvider);

    return SingleChildScrollView(
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.always,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            StringFormField(
              label: 'Nazwa',
              value: '',
              onChanged: draft.setName,
              builder: (context, controller) {
                return TextFormField(
                  controller: controller,
                  maxLength: 30,
                  validator: (value) {
                    if ((value == null) || (value.isEmpty) || (value.length < 5)) {
                      return '';
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
            Row(
              children: [
                Expanded(
                  child: StringFormField(
                    label: 'Ilość węglowodanów na 100g',
                    value: '',
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
                          labelText: 'Weglowodany',
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
                    value: '',
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
                    value: '',
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
                    value: '',
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
