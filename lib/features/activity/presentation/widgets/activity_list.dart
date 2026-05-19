import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../core/domain/model/activity.dart';
import '../../data/providers/activity_provider.dart';

class ActivityList extends HookConsumerWidget {
  const ActivityList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibleLimit = useState(activityListPageSize);
    final activitiesState = ref.watch(activityListStreamProvider);

    return activitiesState.when(
      loading: () => const SafeArea(
        top: false,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => SafeArea(
        top: false,
        child: Center(
          child: TextButton.icon(
            onPressed: () => ref.invalidate(activityListStreamProvider),
            icon: const Icon(Icons.refresh),
            label: const Text('Spróbuj ponownie'),
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
          return const SafeArea(
            top: false,
            child: Center(child: Text('Brak aktywności')),
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
                  return activity.whenOrNull(
                        existing:
                            (
                              id,
                              name,
                              percentagePre,
                              percentagePost,
                              durationMinutes,
                            ) {
                              return _ActivityCard(
                                name: name,
                                percentagePre: percentagePre,
                                percentagePost: percentagePost,
                                durationMinutes: durationMinutes,
                                onTap: () {
                                  context.router.push(
                                    routes.ActivityRoute(activityId: id),
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
          label: const Text('Spróbuj ponownie'),
        ),
      );
    }

    if (!hasMore) {
      return const SizedBox(height: 8);
    }

    return const SizedBox(height: 24);
  }
}

class _ActivityCard extends StatelessWidget {
  final String name;
  final int percentagePre;
  final int percentagePost;
  final int? durationMinutes;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.name,
    required this.percentagePre,
    required this.percentagePost,
    required this.durationMinutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  _MetaPill(
                    icon: Icons.timer,
                    text: _formatDuration(durationMinutes),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDuration(int? minutes) {
    if (minutes == null) {
      return 'Zakończenie ręczne';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes.remainder(60);
    if (hours == 0) {
      return '$minutes min';
    }
    if (remainingMinutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${remainingMinutes.toString().padLeft(2, '0')} min';
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            text,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
