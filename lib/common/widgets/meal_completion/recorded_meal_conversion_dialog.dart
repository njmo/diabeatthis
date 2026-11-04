import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';

import '../../l10n/language.dart';
import '../../meal/recorded_meal_conversion_request.dart';

class RecordedMealConversionDialog extends HookWidget {
  final RecordedMealConversionRequest request;
  const RecordedMealConversionDialog({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final number = NumberFormat('0.########', lang.localeName);
    final suggested = request.currentGrams;
    final controller = useTextEditingController(
      text: suggested == null ? '' : number.format(suggested),
    );
    final form = useMemoized(() => GlobalKey<FormState>());
    double? parse() =>
        double.tryParse(controller.text.trim().replaceAll(',', '.'));
    void confirm() {
      if (form.currentState!.validate()) Navigator.of(context).pop(parse());
    }

    return AlertDialog(
      title: Text(lang.mealConversionReviewTitle),
      scrollable: true,
      content: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request.ingredientName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(request.portionName),
            const SizedBox(height: 12),
            Text(lang.mealConversionReviewExplanation),
            const SizedBox(height: 12),
            Text(
              suggested == null
                  ? lang.mealConversionNoSuggestion
                  : lang.mealConversionCurrentSuggestion(
                      number.format(suggested),
                    ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: lang.mealConversionGramsPerPortion,
                suffixText: 'g',
              ),
              validator: (_) {
                final value = parse();
                return value == null || !value.isFinite || value <= 0
                    ? lang.mealConversionInvalidWeight
                    : null;
              },
              onFieldSubmitted: (_) => confirm(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(lang.commonCancel),
        ),
        FilledButton(
          onPressed: confirm,
          child: Text(lang.mealConversionConfirm),
        ),
      ],
    );
  }
}
