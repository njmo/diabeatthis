import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../data/provider/meal_template_add_provider.dart';
import '../../data/provider/meal_template_draft_provider.dart';
import '../widgets/meal_template_ingredients_list_editor.dart';

@RoutePage()
class AddMealTemplatePage extends HookConsumerWidget {
  const AddMealTemplatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useState(GlobalKey<FormState>());
    final mealDraft = ref.read(mealTemplateDraftProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Meal Template Page')),
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
                        TextFormField(
                          maxLength: 30,
                          validator: (value) {
                            if ((value == null) ||
                                (value.isEmpty) ||
                                (value.length < 5)) {
                              return '';
                            }
                            return null;
                          },
                          onSaved: (value) {
                            print("saving value $value");
                            mealDraft.setName(value!);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Nazwa',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        SingleChildScrollView(
                          child: MealTemplateIngredientsListEditor(),
                        ),
                        InkWell(
                          child: const Text('Add all'),
                          onTap: () async {
                            if (formKey.value.currentState!.validate()) {
                              formKey.value.currentState!.save();
                              final updatedDraft = ref.read(mealTemplateDraftProvider);
                              ref
                                  .watch(mealTemplateAddProvider.notifier)
                                  .addMealTemplate(updatedDraft);
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
}
