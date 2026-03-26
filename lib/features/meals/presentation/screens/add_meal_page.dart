import 'package:auto_route/auto_route.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/date_time_picker.dart';
import '../../../../core/logger/logger.dart';
import '../../../dashboard/data/providers/meal_add_provider.dart';
import '../../../meal_template/data/provider/meal_template_ingredients_list_provider.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import '../widgets/copied_meal_form_field.dart';
import '../widgets/copied_meal_picker.dart';
import '../widgets/meal_ingredients_list_editor.dart';

@RoutePage()
class AddMealPage extends HookConsumerWidget with Logging {
  const AddMealPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useState(GlobalKey<FormState>());
    final mealDraft = ref.read(mealDraftProvider.notifier);
    final dateController = TextEditingController();

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
                    child: Column(
                      children: [
                        TextFormField(
                          maxLength: 30,
                          validator: (value) {
                            if ((value == null) ||
                                (value.isEmpty) ||
                                (value.length < 5)) {
                              return 'Wpisz nazwe posiłku';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            logI("saving value $value");
                            mealDraft.setName(value!);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Nazwa',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        CopiedMealFormField(
                          picker: showCopiedMealPicker,
                          validator: (value) {
                            if (value == null) {
                              return 'Wybierz źródło kopiowania';
                            }
                            return null;
                          },
                          onPicked: (value) async {
                            if (value is CopiedMealFromTemplate) {
                              final ing = await ref.read(
                                getMealIngredientsDraftForMealTemplateProvider(
                                  value.id,
                                ).future,
                              );
                              mealDraft.clearMealIngredients();
                              mealDraft.addMealIngredients(ing);
                            } else if (value is CopiedMealFromMeal) {
                              final ing = await ref.read(
                                getMealIngredientsDraftForMealProvider(
                                  value.id,
                                ).future,
                              );
                              mealDraft.clearMealIngredients();
                              mealDraft.addMealIngredients(ing);
                            }
                          },
                          onSaved: (value) {
                            if (value?.copiedFromMealId != null ||
                                value?.copiedFromTemplateId != null) {
                              mealDraft.setBasedOnMealId(
                                value!.copiedFromMealId,
                              );
                              mealDraft.setMealTemplateId(
                                value.copiedFromTemplateId,
                              );
                            } else {
                              if (value is CopiedMealFromTemplate) {
                                mealDraft.setMealTemplateId(value.id);
                              } else if (value is CopiedMealFromMeal) {
                                mealDraft.setBasedOnMealId(value.id);
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          focusNode: _DisabledFocusNode(),
                          onSaved: (value) {
                            logI("saving value $value");
                            mealDraft.setPlannedAt(DateTime.parse(value!));
                          },
                          controller: dateController,
                          onChanged: (value) {
                            logI("changed value $value");
                          },
                          onTap: () async {
                            final selectedDateTime = await showDateTimePicker(
                              context: context,
                              initialDate: clock.now(),
                              firstDate: clock.now().subtract(
                                const Duration(days: 1),
                              ),
                              lastDate: clock.now().add(
                                const Duration(days: 5),
                              ),
                            );
                            if (selectedDateTime != null) {
                              dateController.text = selectedDateTime
                                  .toIso8601String();
                            }
                          },
                          validator: (value) {
                            if ((value == null) || (value.isEmpty)) {
                              return 'Wybierz date';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            icon: Icon(Icons.calendar_today_rounded),
                            labelText: 'Planned Date',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          child: MealIngredientsListEditor(),
                        ),
                        InkWell(
                          child: const Text('Add all'),
                          onTap: () async {
                            if (formKey.value.currentState!.validate()) {
                              formKey.value.currentState!.save();
                              final updatedDraft = ref.read(mealDraftProvider);
                              ref
                                  .watch(mealAddProvider.notifier)
                                  .addMeal(updatedDraft);
                              context.router.pop();
                            }
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

  Future<CopiedMealType?> showCopiedMealPicker(BuildContext context) {
    return showModalBottomSheet<CopiedMealType>(
      useRootNavigator: false,
      isScrollControlled: true,
      context: context,
      builder: (context) => const CopiedMealPicker(),
    );
  }
}

class _DisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;
}
