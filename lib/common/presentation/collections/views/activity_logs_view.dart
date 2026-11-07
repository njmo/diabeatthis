import 'package:flutter/material.dart';

import '../../../../features/activity/common/widgets/swipe_to_delete_history_entry.dart';
import '../../../../features/activity/data/models/activity_log_summary_data.dart';
import '../../../history/history_day_group.dart';
import '../../../l10n/language.dart';
import '../../../widgets/history_day_section.dart';
import '../../widgets/activity_log_card.dart';
import '../controllers/activity_logs_controller.dart';
import '../models/collection_state.dart';
import 'collection_list_view.dart';

class ActivityLogsView extends StatelessWidget {
  const ActivityLogsView({
    super.key,
    required this.controller,
    this.header = const [],
  });
  final List<Widget> header;
  final ActivityLogsController controller;
  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final groups = groupHistoryByDay(state.items, (item) => item.startedAt);
    return CollectionListView<HistoryDayGroup<ActivityLogSummaryData>>(
      header: header,
      state: CollectionState(
        items: groups,
        loading: state.loading,
        loadingMore: state.loadingMore,
        failed: state.failed,
        hasMore: state.hasMore,
      ),
      emptyLabel: context.lang.activityLogsEmptyList,
      onRetry: controller.retry,
      onLoadMore: controller.loadMore,
      itemBuilder: (_, group) => HistoryDaySection(
        key: ValueKey(group.date),
        date: group.date,
        itemCount: group.items.length,
        itemBuilder: (context, index) {
          final item = group.items[index];
          final card = ActivityLogCard(
            name: item.activityName,
            startedAt: item.startedAt,
            endedAt: item.endedAt,
            onTap: controller.open == null
                ? null
                : () => controller.open!(item),
          );
          if (controller.delete == null) return card;
          return SwipeToDeleteHistoryEntry(
            key: ValueKey(item.id),
            entryKey: 'activity-log-${item.id}',
            onDelete: () async {
              await controller.delete!(item);
            },
            child: card,
          );
        },
      ),
    );
  }
}
