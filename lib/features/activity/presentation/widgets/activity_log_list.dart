import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../core/domain/model/activity_log.dart';
import '../../data/providers/activity_provider.dart';
import 'activity_log_card.dart';
import 'activity_log_list_tail.dart';

class ActivityLogList extends HookConsumerWidget {
  final int? activityId;

  const ActivityLogList({super.key, this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleLimit = useState(activityLogListPageSize);
    final activityLogsState = ref.watch(
      activityLogListStreamProvider(activityId: activityId),
    );

    return activityLogsState.when(
      loading: () => const SafeArea(
        top: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SafeArea(
        top: false,
        child: Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(
              activityLogListStreamProvider(activityId: activityId),
            ),
            icon: const Icon(Icons.refresh),
            label: const Text('Spróbuj ponownie'),
          ),
        ),
      ),
      data: (activityLogs) {
        final visibleActivityLogs = activityLogs
            .take(visibleLimit.value)
            .toList(growable: false);
        final hasMore = visibleActivityLogs.length < activityLogs.length;

        void loadNextPage() {
          if (!hasMore) {
            return;
          }
          visibleLimit.value += activityLogListPageSize;
        }

        if (activityLogs.isEmpty) {
          return const SafeArea(
            top: false,
            child: Center(child: Text('Brak logów aktywności')),
          );
        }

        final bottomPadding = 16 + MediaQuery.viewPaddingOf(context).bottom;

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                final isUserScroll =
                    notification is ScrollUpdateNotification ||
                    notification is OverscrollNotification;
                if (isUserScroll && notification.metrics.extentAfter < 120) {
                  loadNextPage();
                }
                return false;
              },
              child: ListView.separated(
                padding: EdgeInsets.only(bottom: bottomPadding),
                cacheExtent: 0,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemCount: visibleActivityLogs.length + 1,
                itemBuilder: (context, index) {
                  if (index == visibleActivityLogs.length) {
                    return ActivityLogListTail(
                      isLoading: false,
                      hasMore: hasMore,
                      hasError: false,
                      onRetry: loadNextPage,
                    );
                  }

                  final activityLog = visibleActivityLogs[index];
                  return activityLog.whenOrNull(
                        view:
                            (
                              id,
                              name,
                              activityId,
                              startedAt,
                              endedAt,
                              durationMinutes,
                            ) {
                              return ActivityLogCard(
                                name: name,
                                startedAt: startedAt,
                                endedAt: endedAt,
                                onTap: () {
                                  context.router.push(
                                    routes.ActivityLogRoute(activityLogId: id),
                                  );
                                },
                              );
                            },
                      ) ??
                      const SizedBox.shrink();
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
