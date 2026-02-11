import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/mappers/ingredient_draft_mapper.dart';
import '../../data/providers/ingredient_provider.dart';

class IngredientSearch extends HookConsumerWidget {
  const IngredientSearch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState('');
    final valuePicked = useState(-1);
    final ingredients = ref.watch(ingredientsByQueryProvider(query.value));
    final draft = ref.watch(ingredientDraftProvider.notifier);
    final formKey = ref.watch(mealIngredientFormKeyProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.always,
            child: StringFormField(
              label: 'Nazwa',
              value: '',
              onChanged: (value) {
                query.value = value;
              },
              builder: (context, controller) {
                return TextFormField(
                  autofocus: true,
                  controller: controller,
                  maxLength: 30,
                  validator: (value) {
                    if (valuePicked.value < 0) {
                      return '';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    icon: Icon(Icons.search),
                    labelText: 'Nazwa',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              itemBuilder: (context, index) {
                final ingredient = ingredients.asData?.value[index];
                if (ingredient == null) {
                  return SizedBox.shrink();
                }
                return Card(
                  child: ListTile(
                    title: Text(
                      ingredient.name,
                      style: TextStyle(
                        fontWeight: (valuePicked.value == index)
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      'Kalorie: ${ingredient.caloriesKcalPer100g} kcal',
                    ),
                    trailing: ingredient.isReference ? const Icon(Icons.dinner_dining) : null,
                    onTap: () {
                      draft.overrideDraft(ingredient.toSelection());
                      valuePicked.value = index;
                    },
                  ),
                );
              },
              itemCount: ingredients.asData?.value.length ?? 0,
              shrinkWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
