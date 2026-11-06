import 'package:flutter/widgets.dart';

import '../../l10n/language.dart';

String familyPlanAmountLabel(
  BuildContext context,
  Map component,
  Map? ingredient, {
  bool consumed = false,
}) {
  final amount = component[consumed ? 'consumed_amount' : 'amount'] as num?;
  if (amount == null) return context.lang.uiUnknownAmount;
  if (ingredient?['is_reference'] == 1) {
    return context.lang.mealReferencePortions(amount);
  }
  final unit = component['grams_per_portion_used'] as num?;
  return unit == null
      ? context.lang.amountMissingPortionWeight
      : '${amount * unit} g';
}
