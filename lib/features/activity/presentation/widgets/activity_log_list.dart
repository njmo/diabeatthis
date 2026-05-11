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
    final activityLogs = useState<List<ActivityLog>>(const []);
    final nextPage = useState(0);
    final isLoading = useState(false);
    final hasMore = useState(true);
    final error = useState<Object?>(null);

    Future<void> loadNextPage() async {
      if (isLoading.value || !hasMore.value) {
        return;
      }

      isLoading.value = true;
      try {
        await Future<void>.delayed(const Duration(milliseconds: 250));
        if (!context.mounted) return;

        final activityId = this.activityId;
        final page = activityId == null
            ? await ref.read(activityLogListPageProvider(nextPage.value).future)
            : await ref.read(
                activityLogListForActivityPageProvider(
                  activityId: activityId,
                  page: nextPage.value,
                ).future,
              );
        if (!context.mounted) return;

        activityLogs.value = [...activityLogs.value, ...page];
        nextPage.value += 1;
        hasMore.value = page.length == activityLogListPageSize;
        error.value = null;
      } catch (e) {
        if (!context.mounted) return;
        error.value = e;
      } finally {
        if (context.mounted) {
          isLoading.value = false;
        }
      }
    }

    useEffect(() {
      loadNextPage();
      return null;
    }, [activityId]);

    if (activityLogs.value.isEmpty && isLoading.value) {
      return const SafeArea(
        top: false,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (activityLogs.value.isEmpty && error.value != null) {
      return SafeArea(
        top: false,
        child: Center(
          child: TextButton.icon(
            onPressed: loadNextPage,
            icon: const Icon(Icons.refresh),
            label: const Text('Spróbuj ponownie'),
          ),
        ),
      );
    }

    if (activityLogs.value.isEmpty) {
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemCount: activityLogs.value.length + 1,
            itemBuilder: (context, index) {
              if (index == activityLogs.value.length) {
                return ActivityLogListTail(
                  isLoading: isLoading.value,
                  hasMore: hasMore.value,
                  hasError: error.value != null,
                  onRetry: loadNextPage,
                );
              }

              final activityLog = activityLogs.value[index];
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
  }
}
