import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/l10n/language.dart';
import '../../../../common/presentation/widgets/activity_catalog_card.dart';
import '../../data/providers/activity_provider.dart';

class ActivityList extends HookConsumerWidget {
  const ActivityList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleLimit = useState(activityListPageSize);
    final activitiesState = ref.watch(activityListStreamProvider);

    return activitiesState.when(
      loading: () => const SafeArea(
        bottom: false,
        top: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SafeArea(
        bottom: false,
        top: false,
        child: Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(activityListStreamProvider),
            icon: const Icon(Icons.refresh),
            label: Text(context.lang.commonRetry),
          ),
        ),
      ),
      data: (activities) {
        final visibleActivities = activities
            .take(visibleLimit.value)
            .toList(growable: false);
        final hasMore = visibleActivities.length < activities.length;

        void loadNextPage() {
          if (!hasMore) {
            return;
          }
          visibleLimit.value += activityListPageSize;
        }

        if (activities.isEmpty) {
          return SafeArea(
            bottom: false,
            top: false,
            child: Center(child: Text(context.lang.activityEmptyList)),
          );
        }

        final bottomPadding = 16 + MediaQuery.paddingOf(context).bottom;

        return SafeArea(
          bottom: false,
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
                scrollCacheExtent: const ScrollCacheExtent.pixels(0),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemCount: visibleActivities.length + 1,
                itemBuilder: (context, index) {
                  if (index == visibleActivities.length) {
                    return _ActivityListTail(
                      isLoading: false,
                      hasMore: hasMore,
                      hasError: false,
                      onRetry: loadNextPage,
                    );
                  }

                  final activity = visibleActivities[index];
                  return ActivityCatalogCard(
                    name: activity.name,
                    percentagePre: activity.percentagePre,
                    percentagePost: activity.percentagePost,
                    durationMinutes: activity.durationMinutes,
                    onTap: () {
                      context.router.push(
                        routes.ActivityRoute(activityId: activity.id),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActivityListTail extends StatelessWidget {
  final bool isLoading;
  final bool hasMore;
  final bool hasError;
  final VoidCallback onRetry;

  const _ActivityListTail({
    required this.isLoading,
    required this.hasMore,
    required this.hasError,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (hasError) {
      return Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(context.lang.commonRetry),
        ),
      );
    }

    if (!hasMore) {
      return const SizedBox(height: 8);
    }

    return const SizedBox(height: 24);
  }
}
