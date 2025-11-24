import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/date_time_picker.dart';
import '../../../../common/widgets/forms.dart';
import '../../../../core/domain/model/meal.dart' as domain;
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../data/providers/meal_database_provider.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import '../widgets/meal_ingredients_list_editor.dart';

@RoutePage()
class AddMealPage extends HookConsumerWidget {
  const AddMealPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useState(GlobalKey<FormState>());
    final draft = ref.watch(mealDraftProvider);
    final mealDraft = ref.watch(mealDraftProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Meal Page')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Center(
                child: SafeArea(
                  child: Form(
                    key: formKey.value,
                    autovalidateMode: AutovalidateMode.always,
                    child: Column(
                      children: [
                        StringFormField(
                          label: 'Nazwa',
                          value: '',
                          onChanged: mealDraft.setName,
                          builder: (context, controller) {
                            return TextFormField(
                              controller: controller,
                              maxLength: 30,
                              validator: (value) {
                                if ((value == null) ||
                                    (value.isEmpty) ||
                                    (value.length < 5)) {
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
                        StringFormField(
                          label: 'Planned Date',
                          value: draft.plannedAt.toIso8601String(),
                          onChanged: (value) {
                            if (value.isNotEmpty) {
                              final date = DateTime.tryParse(value);
                              if (date != null) {
                                mealDraft.setPlannedAt(DateTime.parse(value));
                              }
                            }
                          },
                          builder: (context, controller) {
                            return TextFormField(
                              focusNode: _DisabledFocusNode(),
                              controller: controller,
                              maxLength: 50,
                              onTap: () async {
                                final selectedDateTime = await showDateTimePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 1),
                                  ),
                                  lastDate: DateTime.now().add(
                                    const Duration(days: 5),
                                  ),
                                );
                                if (selectedDateTime != null) {
                                  mealDraft.setPlannedAt(selectedDateTime);
                                }
                              },
                              validator: (value) {
                                if ((value == null) || (value.isEmpty)) {
                                  return '';
                                }
                                return null;
                              },
                              decoration: const InputDecoration(
                                icon: Icon(Icons.calendar_today_rounded),
                                labelText: 'Planned Date',
                                border: OutlineInputBorder(),
                              ),
                            );
                          },
                        ),
                        SingleChildScrollView(child: MealIngredientsListEditor()),
                        InkWell(
                          child: const Text('Add all'),
                          onTap: () async {
                            final calculatedCarbs = await ref.read(
                              calculatedMacronutrientsProvider.future,
                            );
                            ref
                                .read(mealDraftProvider.notifier)
                                .setCarbs(calculatedCarbs.carbsTotal);

                            final updatedDraft = ref.read(mealDraftProvider);
                            final mealIngredientDrafts = ref.read(
                              mealDraftIngredientsProvider,
                            );

                            print(
                              'Adding ${updatedDraft.name} with carbs ${updatedDraft.carbs} calculated $calculatedCarbs',
                            );
                            final meal = await ref.read(
                              insertMealProvider(updatedDraft).future,
                            );
                            print("Added ${meal.name}");
                            for (final mealIngredient in mealIngredientDrafts) {
                              final ingredient = await ref.read(
                                insertIngredientProvider(
                                  mealIngredient.ingredient,
                                ).future,
                              );
                              print("Added ${(ingredient).name}");
                              final portion = await ref.read(
                                insertPortionProvider(
                                  mealIngredient.ingredientPortion.portion,
                                ).future,
                              );

                              print("Added ${portion?.name ?? 'no portion'}");
                              print("Adding ingredient portion relation");
                              await ref.read(
                                insertIngredientPortionProvider(
                                  ingredient,
                                  portion,
                                  mealIngredient.ingredientPortion.amount,
                                ).future,
                              );
                              await ref.read(
                                insertMealIngredientProvider(
                                  ingredient,
                                  meal,
                                  portion,
                                  mealIngredient.amount,
                                ).future,
                              );
                              print("Added meal ingredient");
                            }
                            context.router.pop();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;
}
