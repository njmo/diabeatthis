import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/widgets/forms.dart';
import '../../../../core/domain/model/ingredient.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/ingredient_provider.dart';

const int _ingredientSearchMaxLength = 120;

class IngredientList extends HookConsumerWidget {
  const IngredientList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState("");
    final ingredients = ref.watch(ingredientsByQueryProvider(query.value));
    final formKey = ref.watch(mealIngredientFormKeyProvider);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SafeArea(
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
                    autofocus: false,
                    controller: controller,
                    maxLength: _ingredientSearchMaxLength,
                    validator: (value) {
                      return '';
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
                        style: TextStyle(fontWeight: FontWeight.normal),
                      ),
                      subtitle: Text('Kalorie: ${ingredient.kcalPer100g} kcal'),
                      trailing: ingredient.isReference
                          ? const Icon(Icons.dinner_dining)
                          : null,
                      onTap: () {
                        ingredient.mapOrNull(
                          existing: (data) {
                            context.router.push(
                              routes.IngredientRoute(ingredientId: data.id),
                            );
                          },
                        );
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
      ),
    );
  }
}
