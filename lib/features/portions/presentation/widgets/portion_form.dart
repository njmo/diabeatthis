import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/portion_provider.dart';

class PortionForm extends HookConsumerWidget {
  const PortionForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(portionDraftProvider.notifier);
    final formKey = ref.watch(mealIngredientFormKeyProvider);

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
                      label: 'Nazwa',
                      value: '',
                      onChanged: draft.setName,
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
                    StringFormField(
                      label: 'Jednostka',
                      value: '',
                      onChanged: draft.setUnitHint,
                      builder: (context, controller) {
                        return TextFormField(
                          controller: controller,
                          maxLength: 30,
                          validator: (value) {
                            if ((value == null) || (value.isEmpty)) {
                              return '';
                            }
                            return null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Jednostka',
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
