import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/activity_provider.dart';

class ActivityForm extends HookConsumerWidget {
  const ActivityForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = ref.watch(mealIngredientFormKeyProvider);
    final activityDraft = ref.watch(activityDraftProvider.notifier);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.always,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StringFormField(
                label: 'Nazwa aktywnosci',
                value: '',
                onChanged: activityDraft.setName,
                builder: (context, controller) {
                  return TextFormField(
                    controller: controller,
                    maxLength: 30,
                    validator: (value) {
                      if ((value == null) || (value.isEmpty) || (value.length < 4)) {
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
            ],
          ),
        ),
      ),
    );
  }
}
