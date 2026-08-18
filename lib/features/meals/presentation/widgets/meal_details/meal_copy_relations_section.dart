import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../../app/router/app_router.dart';
import '../../../../../common/l10n/language.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';

class MealCopyRelationsSection extends StatelessWidget {
  final MealDetailsData details;

  const MealCopyRelationsSection({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final copyUsages = details.copyUsages;
    if (copyUsages.isEmpty) {
      return const SizedBox.shrink();
    }

    return MealSectionTile(
      title: context.lang.mealCopyRelationsTitle,
      children: [
        for (final usage in copyUsages)
          MealCopyUsageTile(
            icon: Icons.call_split,
            title: usage.sourceType,
            mealId: usage.id,
            mealName: usage.name,
            plannedAt: usage.plannedAt,
            status: usage.status,
          ),
      ],
    );
  }
}

class MealCopyUsageTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final int mealId;
  final String mealName;
  final DateTime plannedAt;
  final String? status;

  const MealCopyUsageTile({
    super.key,
    required this.icon,
    required this.title,
    required this.mealId,
    required this.mealName,
    required this.plannedAt,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      mealDateTime(plannedAt),
      if (status != null) mealStatusLabel(status!),
    ];

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text('$title: $mealName'),
      subtitle: Text(subtitleParts.join(' • ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.router.push(MealRoute(mealId: mealId)),
    );
  }
}
