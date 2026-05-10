import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../core/domain/model/activity_log.dart';
import '../../data/providers/activity_provider.dart';

class ActivityList extends HookConsumerWidget {
  const ActivityList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(getActivityLogsProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: activities.when(
          data: (data) {
            if (data.isEmpty) {
              return const Center(child: Text('Brak aktywności'));
            }

            return ListView.separated(
              padding: const EdgeInsets.only(bottom: 16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: data.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final activity = data[index];
                return activity.whenOrNull(
                      view: (id, name, activityId, startedAt, endedAt) {
                        return _ActivityLogCard(
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
            );
          },
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error.toString(), textAlign: TextAlign.center),
            ),
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
        ),
      ),
    );
  }
}

class _ActivityLogCard extends StatelessWidget {
  final String name;
  final DateTime startedAt;
  final DateTime? endedAt;
  final VoidCallback onTap;

  const _ActivityLogCard({
    required this.name,
    required this.startedAt,
    required this.endedAt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = endedAt == null;

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
                  const SizedBox(width: 12),
                  _StatusChip(active: isActive),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MetaPill(
                    icon: Icons.calendar_today,
                    text: _formatDate(startedAt),
                  ),
                  _MetaPill(
                    icon: Icons.access_time,
                    text: _formatTimeRange(startedAt, endedAt),
                  ),
                  _MetaPill(
                    icon: Icons.timer,
                    text: _formatDuration(startedAt, endedAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day.$month.${date.year}';
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static String _formatTimeRange(DateTime startedAt, DateTime? endedAt) {
    final end = endedAt == null ? 'teraz' : _formatTime(endedAt);
    return '${_formatTime(startedAt)} - $end';
  }

  static String _formatDuration(DateTime startedAt, DateTime? endedAt) {
    if (endedAt == null) {
      return 'W trakcie';
    }

    final duration = endedAt.difference(startedAt);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) {
      return '$minutes min';
    }
    return '${hours}h ${minutes.toString().padLeft(2, '0')} min';
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;

  const _StatusChip({required this.active});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = active
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = active
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        active ? 'Aktywna' : 'Zakończona',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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
