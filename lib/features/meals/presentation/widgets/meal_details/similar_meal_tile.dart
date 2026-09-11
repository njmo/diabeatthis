import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../core/domain/model/meal_snapshot.dart';
import '../../../../meal_analysis/domain/models/similar_meal_context.dart';
import '../../../common/widgets/meal_macro_comparison.dart';

class SimilarMealTile extends StatelessWidget {
  final SimilarMealMatch match;
  final VoidCallback onTap;
  final Widget? glucosePreview;
  const SimilarMealTile({
    super.key,
    required this.match,
    required this.onTap,
    this.glucosePreview,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final snapshot = match.meal.snapshot!;
    final number = NumberFormat('0.#', lang.localeName);
    final date = DateFormat(
      'dd.MM.yyyy HH:mm',
      lang.localeName,
    ).format(match.meal.eatenAt.toLocal());
    final theme = Theme.of(context);
    final metadata = [
      match.matchesIngredients
          ? lang.similarMealComposition
          : lang.similarMealMacrosOnly,
      if (match.portionRatio != null)
        lang.similarMealPortionCompact(
          number.format(match.portionRatio! * 100),
        ),
      snapshot.snapshotType == MealSnapshotType.consumed
          ? lang.similarMealsConsumed
          : lang.similarMealsPlanned,
    ].join(' · ');
    return ListTile(
      dense: true,
      minVerticalPadding: 5,
      horizontalTitleGap: 8,
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Expanded(
            child: Text(
              match.meal.name,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: date,
            child: Text(
              DateFormat(
                'dd.MM HH:mm',
                lang.localeName,
              ).format(match.meal.eatenAt.toLocal()),
              style: theme.textTheme.labelSmall,
            ),
          ),
        ],
      ),
      trailing: const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 3),
          MealMacroComparison(
            netCarbs: snapshot.totalNetCarbsG,
            protein: snapshot.totalProteinG,
            fat: snapshot.totalFatG,
            showRatio: false,
            showRatioLabel: false,
          ),
          if (glucosePreview != null) glucosePreview!,
          const SizedBox(height: 2),
          Tooltip(
            message: match.portionRatio == null
                ? metadata
                : lang.similarMealPortion(
                    number.format(match.portionRatio! * 100),
                  ),
            child: Text(
              metadata,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
