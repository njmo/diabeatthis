import 'package:flutter/material.dart';

import '../../../../core/domain/model/activity.dart';
import '../../../l10n/language.dart';
import '../../widgets/activity_catalog_card.dart';
import '../controllers/activities_controller.dart';
import 'collection_list_view.dart';

class ActivitiesView extends StatelessWidget {
  const ActivitiesView({super.key, required this.controller});
  final ActivitiesController controller;
  @override
  Widget build(BuildContext context) => CollectionListView<Activity>(
    state: controller.state,
    emptyLabel: context.lang.activityEmptyList,
    onRetry: controller.retry,
    onLoadMore: controller.loadMore,
    itemBuilder: (_, activity) => ActivityCatalogCard(
      name: activity.name,
      percentagePre: activity.percentagePre,
      percentagePost: activity.percentagePost,
      durationMinutes: activity.durationMinutes,
      onTap: controller.open == null ? null : () => controller.open!(activity),
    ),
  );
}
