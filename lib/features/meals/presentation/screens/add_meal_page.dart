import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/date_time_picker.dart';
import '../../../../common/widgets/forms.dart';
import '../../../dashboard/data/providers/meal_add_provider.dart';
import '../../data/providers/meal_draft_provider.dart';
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
                            final updatedDraft = ref.read(mealDraftProvider);
                            ref.watch(mealAddProvider.notifier).addMeal(updatedDraft);
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
