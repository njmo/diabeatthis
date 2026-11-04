import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/portion_review_row.dart';
import '../../domain/models/meal_photo_review_item.dart';
import 'meal_photo_amount_details.dart';

class MealPhotoAmountTile extends HookWidget {
  const MealPhotoAmountTile({
    super.key,
    required this.item,
    required this.onChanged,
  });
  final MealPhotoReviewItem item;
  final void Function(
    double grams,
    double quantityConfidence,
    double nutritionConfidence,
    bool reviewed,
  )
  onChanged;

  @override
  Widget build(BuildContext context) {
    final input = useTextEditingController(
      text: item.weightGrams == null
          ? ''
          : (item.weightGrams! == item.weightGrams!.roundToDouble()
                ? item.weightGrams!.toInt().toString()
                : item.weightGrams.toString()),
    );
    final grams = useState(item.weightGrams ?? 0.0);
    void change({double? quantity, double? nutrition, bool reviewed = false}) =>
        onChanged(
          grams.value,
          quantity ?? item.quantityConfidence,
          nutrition ?? item.nutritionConfidence,
          reviewed,
        );
    final facts = item.nutritionForPortion;
    return PortionReviewRow(
      name: item.displayName,
      summary: facts == null
          ? ''
          : context.lang.mealPhotoPortionMacros(
              facts.netCarbs.toStringAsFixed(1),
              facts.kcal.round().toString(),
            ),
      reviewed: item.reviewed,
      reviewLabel: context.lang.mealPhotoReviewed,
      onReviewed: item.validWeight
          ? (value) => change(reviewed: value ?? false)
          : null,
      detailsLabel: context.lang.mealPhotoAmountDetails,
      onDetails: () {
        var current = item;
        showDialog<void>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(item.displayName),
              content: SingleChildScrollView(
                child: MealPhotoAmountDetails(
                  item: current,
                  initiallyExpanded: true,
                  onQuantityChanged: (value) {
                    setState(
                      () => current = current.adjust(
                        grams: grams.value,
                        quantityConfidence: value,
                        nutritionConfidence: current.nutritionConfidence,
                        reviewed: false,
                      ),
                    );
                    change(
                      quantity: value,
                      nutrition: current.nutritionConfidence,
                    );
                  },
                  onNutritionChanged: (value) {
                    setState(
                      () => current = current.adjust(
                        grams: grams.value,
                        quantityConfidence: current.quantityConfidence,
                        nutritionConfidence: value,
                        reviewed: false,
                      ),
                    );
                    change(
                      quantity: current.quantityConfidence,
                      nutrition: value,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.lang.commonCloseTooltip),
                ),
              ],
            ),
          ),
        );
      },
      amountField: TextField(
        controller: input,
        decoration: InputDecoration(
          labelText: context.lang.mealPhotoGrams,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 12,
          ),
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        onChanged: (value) {
          grams.value = double.tryParse(value.replaceAll(',', '.')) ?? 0;
          change();
        },
      ),
    );
  }
}
