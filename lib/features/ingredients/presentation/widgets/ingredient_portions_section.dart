import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/form_section.dart';
import '../../../../common/widgets/section_surface.dart';
import '../../data/models/ingredient_portion_data.dart';
import '../utils/reference_ingredient_macro_calculator.dart';
import 'ingredient_section_empty.dart';

class IngredientPortionsSection extends StatelessWidget {
  const IngredientPortionsSection({
    super.key,
    required this.portions,
    this.onEdit,
  });

  final List<IngredientPortionData> portions;
  final ValueChanged<IngredientPortionData>? onEdit;

  @override
  Widget build(BuildContext context) => SectionSurface(
    child: FormSection(
      title: context.lang.ingredientPortionsTitle,
      children: [
        if (portions.isEmpty)
          IngredientSectionEmpty(
            icon: Icons.scale_outlined,
            label: context.lang.ingredientDefinedPortionsEmpty,
          )
        else
          for (var index = 0; index < portions.length; index++) ...[
            if (index > 0) const Divider(),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(portions[index].name),
                      if (portions[index].unitHint.isNotEmpty)
                        Text(
                          portions[index].unitHint,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    '${formatReferenceMacroInput(portions[index].gramsPerPortion)} g',
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    tooltip: context.lang.ingredientEditPortionTooltip,
                    onPressed: () => onEdit!(portions[index]),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
              ],
            ),
          ],
      ],
    ),
  );
}
