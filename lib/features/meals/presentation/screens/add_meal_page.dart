import 'package:auto_route/auto_route.dart';
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/date_time_picker.dart';
import '../../../dashboard/data/providers/meal_add_provider.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../widgets/meal_ingredients_list_editor.dart';

@RoutePage()
class AddMealPage extends HookConsumerWidget {
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
                        TextFormField(
                          focusNode: _DisabledFocusNode(),
                          onSaved: (value) {
                            print("saving value $value");
                            mealDraft.setPlannedAt(DateTime.parse(value!));
                          },
                          controller: dateController,
                          maxLength: 50,
                          onChanged: (value) {
                            print("changed value $value");
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
                              dateController.text = selectedDateTime.toIso8601String();
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
                        ),
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
}

class _DisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;
}
