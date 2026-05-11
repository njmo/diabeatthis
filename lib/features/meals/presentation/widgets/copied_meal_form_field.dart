import 'package:flutter/material.dart';

import '../../data/model/copied_meal_type.dart';

class CopiedMealFormField extends FormField<CopiedMealType?> {
  CopiedMealFormField({
    super.key,
    super.initialValue,
    super.onSaved,
    super.validator,
    required Future<CopiedMealType?> Function(BuildContext context) picker,
    void Function(CopiedMealType? value)? onPicked,
  }) : super(
         builder: (state) {
           final value = state.value;

           String label;
           if (value == null) {
             label = 'Wybierz posiłek lub szablon';
           } else if (value is CopiedMealFromTemplate) {
             label = 'Szablon - ${value.name}';
           } else if (value is CopiedMealFromMeal) {
             label = 'Posiłek - ${value.name}';
           } else {
             label = value.name;
           }

           return Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               InkWell(
                 onTap: () async {
                   final result = await picker(state.context);
                   if (result != null) {
                     onPicked?.call(result);
                     state.didChange(result);
                   }
                 },
                 child: InputDecorator(
                   decoration: InputDecoration(
                     labelText: 'Na podstawie',
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
