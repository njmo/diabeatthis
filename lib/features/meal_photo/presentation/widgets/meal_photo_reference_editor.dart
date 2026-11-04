import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/nutrition/confidence_level.dart';
import '../../../../common/nutrition/reference_ingredient_macro_calculator.dart';
import '../../../../common/widgets/confidence_slider.dart';
import '../../../../core/domain/model/carbs_label_mode.dart';
import '../../domain/models/meal_photo_nutrition.dart';

class MealPhotoReferenceEditor extends HookWidget {
  const MealPhotoReferenceEditor({
    super.key,
    required this.name,
    this.initialNutrition,
    this.initialConfidence = .25,
    this.onConfidenceSaved,
    this.onNameSaved,
  });
  final String name;
  final MealPhotoNutrition? initialNutrition;
  final double initialConfidence;
  final ValueChanged<double>? onConfidenceSaved;
  final ValueChanged<String>? onNameSaved;

  @override
  Widget build(BuildContext context) {
    final nameInput = useTextEditingController(text: name);
    final confidence = useState(
      ConfidenceLevelX.fromDouble01(initialConfidence),
    );
    final form = useMemoized(GlobalKey<FormState>.new);
    final carbs = useTextEditingController(
      text: initialNutrition?.netCarbs.toString() ?? '',
    );
    final extendedCarbs = useTextEditingController(
      text: initialNutrition == null
          ? ''
          : formatReferenceMacroInput(
              referenceExtendedCarbsPer100g(
                fatPer100g: initialNutrition!.fat,
                proteinPer100g: initialNutrition!.protein,
              ),
            ),
    );
    final fatShare = useState(
      referenceFatShare(
        fatPer100g: initialNutrition?.fat ?? 0,
        proteinPer100g: initialNutrition?.protein ?? 0,
      ),
    );
    final fields = [carbs, extendedCarbs];
    final labels = [
      context.lang.ingredientSimpleCarbsLabel,
      context.lang.ingredientExtendedCarbsLabel,
    ];
    double? number(String? value) =>
        double.tryParse((value ?? '').replaceAll(',', '.'));
    return AlertDialog(
      title: Text(
        onNameSaved != null ? context.lang.mealPhotoAddReference : name,
      ),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onNameSaved != null)
                TextFormField(
                  controller: nameInput,
                  decoration: InputDecoration(
                    labelText: context.lang.ingredientNameLabel,
                  ),
                  maxLength: 120,
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.lang.ingredientNameRequired
                      : null,
                ),
              Text(
                context.lang.ingredientReferenceBadge,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(context.lang.ingredientReferenceEditorHint),
              for (var index = 0; index < fields.length; index++)
                TextFormField(
                  controller: fields[index],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: labels[index],
                    suffixText: 'g',
                  ),
                  validator: (value) {
                    final parsed = number(value);
                    return parsed == null || !parsed.isFinite || parsed < 0
                        ? context.lang.mealPhotoManualReferenceInvalid
                        : null;
                  },
                ),
              const SizedBox(height: 12),
              Text(
                context.lang.ingredientEcarbsSplit(
                  ((1 - fatShare.value) * 100).round(),
                  (fatShare.value * 100).round(),
                ),
              ),
              Slider(
                value: fatShare.value,
                divisions: 20,
                label: context.lang.ingredientFatPercentLabel(
                  (fatShare.value * 100).round(),
                ),
                onChanged: (value) => fatShare.value = value,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(context.lang.mealProteinLabel),
                  Text(context.lang.mealFatLabel),
                ],
              ),
              const SizedBox(height: 16),
              ConfidenceSlider(
                value: confidence.value,
                title: context.lang.mealPhotoNutritionConfidence,
                onChanged: (value) => confidence.value = value,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.lang.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            if (!form.currentState!.validate()) return;
            onConfidenceSaved?.call(confidence.value.toDouble01());
            onNameSaved?.call(nameInput.text.trim());
            Navigator.pop(
              context,
              MealPhotoNutrition(
                carbs: number(carbs.text)!,
                fiber: initialNutrition?.fiber ?? 0,
                fat: referenceFatPer100g(
                  extendedCarbsPer100g: number(extendedCarbs.text)!,
                  fatShare: fatShare.value,
                ),
                protein: referenceProteinPer100g(
                  extendedCarbsPer100g: number(extendedCarbs.text)!,
                  fatShare: fatShare.value,
                ),
                carbsLabelMode: CarbsLabelMode.eu,
              ),
            );
          },
          child: Text(context.lang.commonSave),
        ),
      ],
    );
  }
}
