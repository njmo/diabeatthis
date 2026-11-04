import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../controllers/activity_log_details_controller.dart';
import '../widgets/activity_log_body.dart';
import '../widgets/activity_log_edit_time_button.dart';

@RoutePage()
class ActivityLogPage extends ConsumerWidget {
  final int activityLogId;

  const ActivityLogPage({super.key, required this.activityLogId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      activityLogDetailsControllerProvider(activityLogId, includeContext: true),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(context.lang.activityLogTitle),
        actions: [
          if (state.asData?.value.data.endedAt != null)
            ActivityLogEditTimeButton(
              log: state.asData!.value.data,
              compact: true,
            ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(context.lang.activityError(error))),
        data: (state) => ActivityLogBody(
          state: state,
          onTimestampSelected: (timestamp) => ref.read(
            activityLogDetailsControllerProvider(activityLogId, includeContext: true).notifier,
          ).selectTimestamp(timestamp),
        ),
      ),
    );
  }

}
