import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../data/mappers/ingredient_draft_mapper.dart';
import '../../data/providers/ingredient_provider.dart';

class IngredientSearch extends HookConsumerWidget {
  const IngredientSearch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState('');
    final ingredients = ref.watch(ingredientsByQueryProvider(query.value));

    return SingleChildScrollView(
      child: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 12,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 30,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Wyszukaj składnik po nazwie",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                Column(
                  children: [
                    StringFormField(
                      label: 'Nazwa',
                      value: '',
                      onChanged: (String asd) {},
                      builder: (context, controller) {
                        return TextFormField(
                          autofocus: true,
                          controller: controller,
                          onChanged: (value) {
                            query.value = value;
                          },
                          maxLength: 30,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Enter a title.';
                            } else if (value.length > 20) {
                              return 'Limit the title to 20 characters.';
                            } else {
                              return null;
                            }
                          },
                          decoration: const InputDecoration(
                            icon: Icon(Icons.search),
                            labelText: 'Nazwa',
                            border: OutlineInputBorder(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 16),
                    SingleChildScrollView(
                      child: ListView.builder(
                        itemBuilder: (context, index) {
                          final ingredient = ingredients.asData?.value[index];
                          if (ingredient == null) {
                            return SizedBox.shrink();
                          }
                          return Card(
                            child: ListTile(
                              title: Text(ingredient.name),
                              subtitle: Text(
                                'Kalorie: ${ingredient.caloriesKcalPer100g} kcal',
                              ),
                              onTap: () {
                                Navigator.of(
                                  context,
                                ).pop(ingredient.toSelection());
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
