import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../../app/router/app_router.dart';
import '../../../../../common/l10n/language.dart';
import '../../../data/models/meal_details_data.dart';
import 'meal_detail_components.dart';
import 'meal_detail_formatters.dart';

class MealBasicInfoSection extends StatelessWidget {
  final MealDetailsData details;

  const MealBasicInfoSection({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    final meal = details.meal;

    return MealSectionTile(
      title: context.lang.mealBasicInfoTitle,
      initiallyExpanded: true,
      children: [
        MealInfoRow(label: context.lang.mealNameTypeLabel, value: meal.name),
        MealInfoRow(
          label: context.lang.mealStatusLabel,
          value: mealStatusLabel(meal.status),
        ),
        MealInfoRow(
          label: context.lang.mealPlannedAtLabel,
          value: mealDateTime(meal.plannedAt),
        ),
        MealInfoRow(
          label: context.lang.mealSummarizedAtLabel,
          value: mealDateTimeOrDash(meal.summarizedAt),
        ),
        MealInfoRow(
          label: context.lang.mealCreatedAtLabel,
          value: mealDateTime(meal.createdAt),
        ),
        MealInfoRow(
          label: context.lang.mealUpdatedAtLabel,
          value: mealDateTime(meal.updatedAt),
        ),
        MealInfoRow(
          label: context.lang.mealNotesLabel,
          value: fallbackText(meal.notes),
        ),
        MealIconInfoRow(
          icon: meal.isSynced ? Icons.cloud_done : Icons.edit_location_alt,
          label: context.lang.mealSyncLabel,
          value: meal.isSynced
              ? context.lang.mealSynced
              : context.lang.mealLocal,
        ),
        if (meal.basedOnMealId != null)
          BasedOnMealRow(meal: meal, source: details.copySource),
        if (meal.mealTemplateId != null)
          MealInfoRow(
            label: context.lang.mealBaseTemplateLabel,
            value: '#${meal.mealTemplateId}',
          ),
      ],
    );
  }
}

class BasedOnMealRow extends StatelessWidget {
  final MealRecordData meal;
  final MealCopySourceData? source;

  const BasedOnMealRow({super.key, required this.meal, required this.source});

  @override
  Widget build(BuildContext context) {
    final basedOnMealId = meal.basedOnMealId;
    if (basedOnMealId == null) {
      return const SizedBox.shrink();
    }
    final sourceName = source?.name ?? '#$basedOnMealId';

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.copy_all),
      title: Text(context.lang.mealBasedOnTitle(sourceName)),
      trailing: TextButton.icon(
        icon: const Icon(Icons.open_in_new),
        label: Text('#$basedOnMealId'),
        onPressed: () => context.router.push(MealRoute(mealId: basedOnMealId)),
      ),
    );
  }
}
