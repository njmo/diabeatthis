import 'package:flutter/material.dart';

import '../../../core/domain/model/activity.dart';
import '../../../features/activity/presentation/widgets/activity_details_card.dart';
import '../../l10n/language.dart';
import '../collections/controllers/activity_logs_controller.dart';
import '../collections/views/activity_logs_view.dart';

/// Shared definition preview; edit controls belong to the source's page toolbar.
class ActivityDefinitionView extends StatelessWidget {
  const ActivityDefinitionView({
    super.key,
    required this.activity,
    required this.logs,
  });
  final Activity activity;
  final ActivityLogsController logs;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: ActivityDetailsCard(
          name: activity.name,
          percentagePre: activity.percentagePre,
          percentagePost: activity.percentagePost,
          durationMinutes: activity.durationMinutes,
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text(
          context.lang.activityLogsTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      Expanded(child: ActivityLogsView(controller: logs)),
    ],
  );
}
