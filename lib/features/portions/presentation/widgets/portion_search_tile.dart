import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/portions/standard_portion_names.dart';
import '../../../../common/widgets/sheet_choice_tile.dart';
import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../data/drafts/portion_draft.dart';
import '../../data/providers/portion_provider.dart';

class PortionSearchTile extends ConsumerWidget {
  final PortionSelection portion;
  final IngredientDraft? ingredient;
  final bool selected;
  final VoidCallback onTap;

  const PortionSearchTile({
    required this.portion,
    required this.selected,
    required this.onTap,
    this.ingredient,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final name = portion.map(
      draft: (value) => value.name,
      existing: (value) => value.name,
      empty: (_) => '',
    );
    final unit = portion.map(
      draft: (value) => value.unitHint,
      existing: (value) => value.unitHint,
      empty: (_) => '',
    );
    final title = localizedPortionName(name, lang);
    final assignedIngredient = ingredient;
    final weight = assignedIngredient == null
        ? null
        : ref.watch(gramsPerPortionProvider(assignedIngredient, portion));
    final subtitle = weight == null
        ? (unit.isEmpty ? lang.portionNoUnit : unit)
        : weight.when(
            data: (grams) => grams == null || grams <= 0
                ? lang.amountMissingPortionWeight
                : lang.amountPortionWeightDescription(
                    NumberFormat.decimalPattern(lang.localeName).format(grams),
                    title,
                    unit.isEmpty ? 'g' : unit,
                  ),
            error: (_, _) => lang.amountMissingPortionWeight,
            loading: () => lang.amountLoadingPortionWeight,
          );
    return SheetChoiceTile(
      icon: Icons.local_dining_outlined,
      title: title,
      subtitle: subtitle,
      selected: selected,
      onTap: onTap,
    );
  }
}
