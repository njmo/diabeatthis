import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/theme/application_accent_colors.dart';
import '../../../../common/widgets/section_surface.dart';
import '../../data/model/copied_meal_type.dart';

class CopiedMealSourceCard extends StatelessWidget {
  const CopiedMealSourceCard({super.key, required this.source, this.onChange});

  final CopiedMealType source;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) => SectionSurface(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Icon(
          Icons.content_copy_rounded,
          color: ApplicationAccentColors.warm(Theme.of(context).brightness),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.lang.mealFlowCopiedSource(source.name),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                MaterialLocalizations.of(context).formatMediumDate(source.date),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (onChange != null)
          TextButton(
            onPressed: onChange,
            child: Text(context.lang.mealFlowChange),
          ),
      ],
    ),
  );
}
