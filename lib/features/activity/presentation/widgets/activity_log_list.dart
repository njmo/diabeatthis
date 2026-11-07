import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/presentation/collections/controllers/activity_logs_controller.dart';
import '../../../../common/presentation/collections/models/collection_state.dart';
import '../../../../common/presentation/collections/views/activity_logs_view.dart';
import '../../../../common/presentation/details/activity_definition_view.dart';
import '../../../../core/domain/model/activity.dart';
import '../../common/controllers/activity_actions_controller.dart';
import '../../data/providers/activity_provider.dart';
import '../utils/delete_activity_history_entry.dart';

class ActivityLogList extends HookConsumerWidget {
  const ActivityLogList({super.key, this.activityId, this.definition});
  final Activity? definition;
  final int? activityId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionPending = ref
        .watch(activityActionsControllerProvider)
        .isLoading;
    final limit = useState(activityLogListPageSize);
    final source = ref.watch(
      activityLogListStreamProvider(activityId: activityId),
    );
    final all = source.value ?? const [];
    final controller = PatientActivityLogsController(
      state: CollectionState(
        items: all.take(limit.value).toList(),
        loading: source.isLoading,
        failed: source.hasError,
        hasMore: all.length > limit.value,
      ),
      open: (item) =>
          context.router.push(routes.ActivityLogRoute(activityLogId: item.id)),
      delete: actionPending
          ? null
          : (item) async {
              await deleteActivityHistoryEntry(context, ref, item);
              return false;
            },
      onLoadMore: () {
        if (all.length > limit.value) limit.value += activityLogListPageSize;
      },
      onRetry: () =>
          ref.invalidate(activityLogListStreamProvider(activityId: activityId)),
    );
    return SafeArea(
      bottom: false,
      top: false,
      child: definition == null
          ? ActivityLogsView(controller: controller)
          : ActivityDefinitionView(activity: definition!, logs: controller),
    );
  }
}
