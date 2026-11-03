import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../../app/router/app_router.dart';
import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/history_link_card.dart';
import '../../../domain/models/meal_origin_review.dart';
import 'meal_detail_formatters.dart';

/// Inline origin metadata belongs to the portion, not application decisions.
class MealOriginCard extends StatelessWidget {
  const MealOriginCard({super.key, required this.origin});
  final MealOriginReview origin;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final source = origin.sourceId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.copy_all_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lang.mealOriginTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (source != null) ...[
          if (origin.source != null)
            HistoryLinkCard(
              title: lang.mealBasedOnTitle(origin.source!.name),
              icon: Icons.restaurant_outlined,
              subtitle: '#$source',
              onTap: () => context.router.push(MealRoute(mealId: source)),
            )
          else
            Text(lang.mealCopySourceUnavailable(source)),
        ],
        if (origin.templateId != null)
          Text('${lang.mealBaseTemplateLabel}: #${origin.templateId}'),
        if (origin.usages.isNotEmpty) ...[
          Text(
            lang.mealCopyRelationsTitle,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          for (final usage in origin.usages)
            HistoryLinkCard(
              title: usage.name,
              subtitle:
                  '${mealDateTime(usage.plannedAt.toLocal())} · ${mealStatusLabel(usage.status)}',
              icon: Icons.call_split,
              onTap: () => context.router.push(MealRoute(mealId: usage.id)),
            ),
        ],
      ],
    );
  }
}
