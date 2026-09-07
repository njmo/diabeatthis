import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../data/model/copied_meal_type.dart';

class CopiedMealFormField extends FormField<CopiedMealType?> {
  CopiedMealFormField({
    super.key,
    super.initialValue,
    super.validator,
    required Future<CopiedMealType?> Function(BuildContext context) picker,
    required Future<bool> Function(CopiedMealType) onPicked,
  }) : super(
         builder: (state) {
           final value = state.value;

           String label;
           if (value == null) {
             label = state.context.lang.copiedMealEmptyLabel;
           } else if (value is CopiedMealFromTemplate) {
             label = state.context.lang.copiedMealTemplateLabel(value.name);
           } else if (value is CopiedMealFromMeal) {
             label = state.context.lang.copiedMealMealLabel(value.name);
           } else {
             label = value.name;
           }

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               InkWell(
                 onTap: () async {
                   final result = await picker(state.context);
                   if (result != null && state.mounted) {
                     final applied = await onPicked(result);
                     if (applied && state.mounted) {
                       state.didChange(result);
                     }
                   }
                 },
                 child: InputDecorator(
                   decoration: InputDecoration(
                     labelText: state.context.lang.copiedMealFieldLabel,
                     errorText: state.errorText,
                     border: const OutlineInputBorder(),
                   ),
                   child: Text(label),
                 ),
               ),
             ],
           );
         },
       );
}
