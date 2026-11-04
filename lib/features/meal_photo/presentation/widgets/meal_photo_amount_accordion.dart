import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/meal_photo_review_item.dart';
import 'meal_photo_amount_tile.dart';

class MealPhotoAmountAccordion extends HookWidget {
  const MealPhotoAmountAccordion({
    super.key,
    required this.items,
    required this.onChanged,
  });
  final List<MealPhotoReviewItem> items;
  final void Function(
    String id,
    double grams,
    double quantity,
    double nutrition,
    bool reviewed,
  )
  onChanged;

  @override
  Widget build(BuildContext context) {
    final active = useState<String?>(
      items.where((item) => !item.reviewed).firstOrNull?.proposal.id,
    );
    return Column(
      children: items.map((item) {
        final expanded = active.value == item.proposal.id;
        if (!expanded) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              item.reviewed
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
            ),
            title: Text(item.displayName),
            trailing: Text('${item.weightGrams?.toStringAsFixed(0) ?? "—"} g'),
            onTap: () => active.value = item.proposal.id,
          );
        }
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MealPhotoAmountTile(
                  item: item,
                  onChanged: (grams, quantity, nutrition, reviewed) {
                    onChanged(
                      item.proposal.id,
                      grams,
                      quantity,
                      nutrition,
                      reviewed,
                    );
                    if (reviewed) {
                      active.value = items
                          .where(
                            (other) =>
                                other.proposal.id != item.proposal.id &&
                                !other.reviewed,
                          )
                          .firstOrNull
                          ?.proposal
                          .id;
                    }
                  },
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: item.validWeight
                      ? () {
                          onChanged(
                            item.proposal.id,
                            item.weightGrams!,
                            item.quantityConfidence,
                            item.nutritionConfidence,
                            true,
                          );
                          active.value = items
                              .where(
                                (other) =>
                                    other.proposal.id != item.proposal.id &&
                                    !other.reviewed,
                              )
                              .firstOrNull
                              ?.proposal
                              .id;
                        }
                      : null,
                  child: Text(context.lang.mealPhotoAcceptPortion),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
